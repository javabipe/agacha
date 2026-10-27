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
        case calibrating(frames: Int, hipSum: Double, torsoSum: Double)
        case ready(standingHipY: Double, torso: Double)
    }

    private var phase: Phase = .calibrating(frames: 0, hipSum: 0, torsoSum: 0)
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
        case let .calibrating(frames, hipSum, torsoSum):
            let frames = frames + 1
            let hipSum = hipSum + measure.hipY
            let torsoSum = torsoSum + measure.torso
            if frames >= tuning.calibrationFrames {
                let count = Double(frames)
                phase = .ready(standingHipY: hipSum / count, torso: torsoSum / count)
                posture = .standing
                standingSince = time
                lastCrouch = 0
                return reading(isCalibrated: true)
            }
            phase = .calibrating(frames: frames, hipSum: hipSum, torsoSum: torsoSum)
            return PostureReading(posture: .unknown, crouchIndex: nil, isCalibrated: false)

        case .ready(var standingHipY, var torso):
            let crouch = (measure.hipY - standingHipY) / torso
            lastCrouch = crouch
            applyHysteresis(crouch: crouch, time: time, tuning: tuning)

            // Recalibração lenta: acompanha quem anda para frente/trás enquanto está em pé.
            if posture == .standing, let since = standingSince,
               time - since > tuning.recalibrationHold, crouch < tuning.standEnter {
                let rate = tuning.recalibrationRate
                standingHipY += (measure.hipY - standingHipY) * rate
                torso += (measure.torso - torso) * rate
                phase = .ready(standingHipY: standingHipY, torso: torso)
            }
            return reading(isCalibrated: true)
        }
    }

    // MARK: - Privado

    private struct Measure {
        var hipY: Double
        var torso: Double
    }

    private static func measure(_ skeleton: Skeleton, tuning: PostureTuning) -> Measure? {
        guard let shoulders = skeleton.midpoint(of: [.leftShoulder, .rightShoulder], minConfidence: tuning.minConfidence),
              let hips = skeleton.midpoint(of: [.leftHip, .rightHip], minConfidence: tuning.minConfidence)
        else { return nil }
        let torso = hypot(hips.x - shoulders.x, hips.y - shoulders.y)
        guard torso > 0.02 else { return nil }
        return Measure(hipY: hips.y, torso: torso)
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
