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
    private enum Phase: Sendable {
        case calibrating(frames: Int, hipSum: Double, shoulderSum: Double, torsoSum: Double)
        case ready(standingHipY: Double, standingShoulderY: Double, torso: Double)
    }

    private var phase: Phase = .calibrating(frames: 0, hipSum: 0, shoulderSum: 0, torsoSum: 0)
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
        case let .calibrating(frames, hipSum, shoulderSum, torsoSum):
            // A calibração exige ombros e quadris visíveis (criança em pé).
            guard let hipY = measure.hipY, let shoulderY = measure.shoulderY, let torso = measure.torso else {
                return holdOrLose(at: time, tuning: tuning)
            }
            let frames = frames + 1
            let hipSum = hipSum + hipY
            let shoulderSum = shoulderSum + shoulderY
            let torsoSum = torsoSum + torso
            if frames >= tuning.calibrationFrames {
                let count = Double(frames)
                phase = .ready(standingHipY: hipSum / count, standingShoulderY: shoulderSum / count,
                               torso: torsoSum / count)
                posture = .standing
                standingSince = time
                lastCrouch = 0
                return reading(isCalibrated: true)
            }
            phase = .calibrating(frames: frames, hipSum: hipSum, shoulderSum: shoulderSum, torsoSum: torsoSum)
            return PostureReading(posture: .unknown, crouchIndex: nil, isCalibrated: false)

        case .ready(var standingHipY, var standingShoulderY, var torso):
            // Quadril é a medida da especificação; se o Vision o perder (comum ao agachar de frente),
            // os ombros, que também descem, servem de reserva.
            let crouch: Double
            if let hipY = measure.hipY {
                crouch = (hipY - standingHipY) / torso
            } else if let shoulderY = measure.shoulderY {
                crouch = (shoulderY - standingShoulderY) / torso
            } else {
                return holdOrLose(at: time, tuning: tuning)
            }
            lastCrouch = crouch
            applyHysteresis(crouch: crouch, time: time, tuning: tuning)

            // Recalibração lenta: acompanha quem anda para frente/trás enquanto está em pé.
            if posture == .standing, let since = standingSince,
               time - since > tuning.recalibrationHold, crouch < tuning.standEnter {
                let rate = tuning.recalibrationRate
                if let hipY = measure.hipY { standingHipY += (hipY - standingHipY) * rate }
                if let shoulderY = measure.shoulderY { standingShoulderY += (shoulderY - standingShoulderY) * rate }
                if let current = measure.torso { torso += (current - torso) * rate }
                phase = .ready(standingHipY: standingHipY, standingShoulderY: standingShoulderY, torso: torso)
            }
            return reading(isCalibrated: true)
        }
    }

    // MARK: - Privado

    private struct Measure {
        var hipY: Double?
        var shoulderY: Double?
        /// Só quando ombros e quadris foram vistos no mesmo quadro.
        var torso: Double?
    }

    private static func measure(_ skeleton: Skeleton, tuning: PostureTuning) -> Measure? {
        let shoulders = skeleton.midpoint(of: [.leftShoulder, .rightShoulder], minConfidence: tuning.minConfidence)
        let hips = skeleton.midpoint(of: [.leftHip, .rightHip], minConfidence: tuning.minConfidence)
        guard shoulders != nil || hips != nil else { return nil }
        var torso: Double?
        if let shoulders, let hips {
            let length = hypot(hips.x - shoulders.x, hips.y - shoulders.y)
            if length > 0.02 { torso = length }
        }
        return Measure(hipY: hips?.y, shoulderY: shoulders?.y, torso: torso)
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
