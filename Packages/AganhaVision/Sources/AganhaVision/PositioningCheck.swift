import AganhaCore
import Foundation

public enum PositioningIssue: String, Sendable, Equatable {
    case noHead
    case noFeet
    case cutOff
}

public struct PersonCheck: Sendable, Equatable {
    public let slot: ChildSlot
    public let issue: PositioningIssue?
    /// Os dois pulsos acima do nariz (gesto de "começar").
    public let raisingBothArms: Bool

    public var isReady: Bool { issue == nil }
}

public struct PositioningReport: Sendable, Equatable {
    /// Só as pessoas com vaga, em ordem de vaga.
    public let people: [PersonCheck]
    /// Pessoas além das 6 vagas.
    public let extraPeople: Int
    /// Quantas pessoas são necessárias para começar (2 no jogo, 1 no treino solo).
    public let minPlayers: Int

    public static let empty = PositioningReport(people: [], extraPeople: 0, minPlayers: 2)
    public var allReady: Bool { people.count >= minPlayers && people.allSatisfy(\.isReady) }
    public var firstProblem: PersonCheck? { people.first { !$0.isReady } }
    public var readySlots: [ChildSlot] { people.filter(\.isReady).map(\.slot) }
    /// Alguém pronto está com os dois braços para cima.
    public var anyRaisingBothArms: Bool { people.contains { $0.isReady && $0.raisingBothArms } }
}

/// Confere se cada pessoa aparece inteira (cabeça aos pés) antes de começar a partida.
public enum PositioningCheck {
    public static let edgeMargin = 0.02

    public static func evaluate(_ analysis: FrameAnalysis, minConfidence: Double = 0.3, minPlayers: Int = 2) -> PositioningReport {
        let slotted = analysis.people.compactMap { person -> PersonCheck? in
            guard let slot = person.slot else { return nil }
            return check(person.skeleton, slot: slot, minConfidence: minConfidence)
        }
        return PositioningReport(people: slotted.sorted { $0.slot < $1.slot },
                                 extraPeople: analysis.people.count - slotted.count, minPlayers: minPlayers)
    }

    static func check(_ skeleton: Skeleton, slot: ChildSlot, minConfidence: Double) -> PersonCheck {
        func seen(_ names: [JointName]) -> Bool {
            names.allSatisfy { (skeleton.joints[$0]?.confidence ?? 0) >= minConfidence }
        }
        let keyJoints: [JointName] = [.nose, .leftShoulder, .rightShoulder, .leftHip, .rightHip, .leftAnkle, .rightAnkle]

        let issue: PositioningIssue?
        if !seen([.nose]) {
            issue = .noHead
        } else if !seen([.leftAnkle, .rightAnkle]) {
            issue = .noFeet
        } else if keyJoints.contains(where: { !isInside(skeleton.joints[$0]) }) {
            issue = .cutOff
        } else {
            issue = nil
        }

        var raising = false
        if let nose = skeleton.joints[.nose], nose.confidence >= minConfidence,
           seen([.leftWrist, .rightWrist]),
           let left = skeleton.joints[.leftWrist], let right = skeleton.joints[.rightWrist] {
            raising = left.y < nose.y - 0.03 && right.y < nose.y - 0.03
        }
        return PersonCheck(slot: slot, issue: issue, raisingBothArms: raising)
    }

    private static func isInside(_ joint: Joint?) -> Bool {
        guard let joint else { return false }
        let range = edgeMargin...(1 - edgeMargin)
        return range.contains(joint.x) && range.contains(joint.y)
    }
}
