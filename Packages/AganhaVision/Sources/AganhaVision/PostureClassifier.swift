import AganhaCore
import Foundation

public struct PostureReading: Sendable, Equatable {
    public var posture: Posture
    /// `(hipMid.y − standingHipY) / torsoLength`; nil enquanto não há medida.
    public var crouchIndex: Double?
    public var isCalibrated: Bool

    public init(posture: Posture, crouchIndex: Double?, isCalibrated: Bool) {
        self.posture = posture
        self.crouchIndex = crouchIndex
        self.isCalibrated = isCalibrated
    }
}

/// Classificador por criança. Uma instância por vaga; mantém calibração e histerese.
public struct PostureClassifier: Sendable {
    private struct Average: Sendable {
        var sum = 0.0
        var samples = 0

        var mean: Double? { samples == 0 ? nil : sum / Double(samples) }

        mutating func add(_ value: Double?) {
            guard let value else { return }
            sum += value
            samples += 1
        }
    }

    private struct CalibrationSums: Sendable {
        var frames = 0
        var hip = Average()
        var shoulder = Average()
        var nose = Average()
        var torso = Average()
    }

    /// Alturas de referência "em pé" (y para baixo) e escala. Cada junta é opcional: quem está perto
    /// da câmera pode ter calibrado sem ombros/quadris.
    private struct Reference: Sendable {
        var hipY: Double?
        var shoulderY: Double?
        var noseY: Double?
        var torso: Double
    }

    private enum Phase: Sendable {
        case calibrating(CalibrationSums)
        case ready(Reference)
    }

    private var phase: Phase = .calibrating(CalibrationSums())
    private var posture: Posture = .unknown
    private var lastCrouch: Double?
    private var pendingTarget: Posture?
    private var pendingSince: TimeInterval = 0
    private var lastValid: TimeInterval?
    private var standingSince: TimeInterval?

    public init() {}

    public mutating func reset() {
        self = PostureClassifier()
    }

    /// Atualiza com o esqueleto do quadro (ou nil se a pessoa não foi vista) no instante `time` (s).
    public mutating func update(skeleton: Skeleton?, at time: TimeInterval, tuning: PostureTuning) -> PostureReading {
        guard let skeleton, let measure = Self.measure(skeleton, tuning: tuning) else {
            return holdOrLose(at: time, tuning: tuning)
        }
        lastValid = time

        switch phase {
        case .calibrating(var sums):
            sums.frames += 1
            sums.hip.add(measure.hipY)
            sums.shoulder.add(measure.shoulderY)
            sums.nose.add(measure.noseY)
            sums.torso.add(measure.torso)
            guard sums.frames >= tuning.calibrationFrames else {
                phase = .calibrating(sums)
                return PostureReading(posture: .unknown, crouchIndex: nil, isCalibrated: false)
            }
            // Sem tronco visível (pessoa muito perto), usa uma escala padrão em fração do quadro.
            phase = .ready(Reference(hipY: sums.hip.mean, shoulderY: sums.shoulder.mean, noseY: sums.nose.mean,
                                     torso: sums.torso.mean ?? tuning.noseFallbackScale))
            posture = .standing
            standingSince = time
            lastCrouch = 0
            return reading(isCalibrated: true)

        case .ready(var reference):
            guard let crouch = Self.crouchIndex(measure, reference: reference) else {
                return holdOrLose(at: time, tuning: tuning)
            }
            lastCrouch = crouch
            applyHysteresis(crouch: crouch, time: time, tuning: tuning)

            // Recalibração lenta: acompanha quem anda para frente/trás enquanto está em pé.
            if posture == .standing, let since = standingSince,
               time - since > tuning.recalibrationHold, crouch < tuning.standEnter {
                let rate = tuning.recalibrationRate
                func follow(_ reference: inout Double?, _ value: Double?) {
                    if let value, let current = reference { reference = current + (value - current) * rate }
                }
                follow(&reference.hipY, measure.hipY)
                follow(&reference.shoulderY, measure.shoulderY)
                follow(&reference.noseY, measure.noseY)
                if let current = measure.torso { reference.torso += (current - reference.torso) * rate }
                phase = .ready(reference)
            }
            return reading(isCalibrated: true)
        }
    }

    /// Quadril é a medida da especificação; se o Vision o perder (comum ao agachar de frente) ou a pessoa
    /// estiver perto demais, usa ombros e, por último, o nariz. Tudo normalizado pelo tronco.
    private static func crouchIndex(_ measure: Measure, reference: Reference) -> Double? {
        let candidates = [(measure.hipY, reference.hipY), (measure.shoulderY, reference.shoulderY),
                          (measure.noseY, reference.noseY)]
        for (current, standing) in candidates {
            if let current, let standing { return (current - standing) / reference.torso }
        }
        return nil
    }

    // MARK: - Privado

    private struct Measure {
        var hipY: Double?
        var shoulderY: Double?
        var noseY: Double?
        /// Só quando ombros e quadris foram vistos no mesmo quadro.
        var torso: Double?
    }

    private static func measure(_ skeleton: Skeleton, tuning: PostureTuning) -> Measure? {
        let shoulders = skeleton.midpoint(of: [.leftShoulder, .rightShoulder], minConfidence: tuning.minConfidence)
        let hips = skeleton.midpoint(of: [.leftHip, .rightHip], minConfidence: tuning.minConfidence)
        let nose = skeleton.midpoint(of: [.nose], minConfidence: tuning.minConfidence)
        guard shoulders != nil || hips != nil || nose != nil else { return nil }
        var torso: Double?
        if let shoulders, let hips {
            let length = hypot(hips.x - shoulders.x, hips.y - shoulders.y)
            if length > 0.02 { torso = length }
        }
        return Measure(hipY: hips?.y, shoulderY: shoulders?.y, noseY: nose?.y, torso: torso)
    }

    private mutating func holdOrLose(at time: TimeInterval, tuning: PostureTuning) -> PostureReading {
        if let lastValid, time - lastValid <= tuning.lostTimeout {
            return reading(isCalibrated: isCalibrated)
        }
        posture = .unknown
        pendingTarget = nil
        standingSince = nil
        lastCrouch = nil
        return reading(isCalibrated: isCalibrated)
    }

    private var isCalibrated: Bool {
        if case .ready = phase { return true }
        return false
    }

    private func reading(isCalibrated: Bool) -> PostureReading {
        PostureReading(posture: posture, crouchIndex: lastCrouch, isCalibrated: isCalibrated)
    }

    private mutating func applyHysteresis(crouch: Double, time: TimeInterval, tuning: PostureTuning) {
        let target: Posture? = if crouch > tuning.crouchEnter {
            .crouching
        } else if crouch < tuning.standEnter {
            .standing
        } else {
            nil
        }

        guard let target, target != posture else {
            pendingTarget = nil
            return
        }
        if pendingTarget != target {
            pendingTarget = target
            pendingSince = time
        }
        if time - pendingSince >= tuning.debounce {
            posture = target
            pendingTarget = nil
            standingSince = target == .standing ? time : nil
        }
    }
}
