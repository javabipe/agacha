import Foundation

public enum JointName: String, Codable, CaseIterable, Sendable {
    case nose
    case leftShoulder, rightShoulder
    case leftElbow, rightElbow
    case leftWrist, rightWrist
    case leftHip, rightHip
    case leftKnee, rightKnee
    case leftAnkle, rightAnkle
}

/// Junta normalizada: x e y em 0...1, com y crescendo para baixo (origem no canto superior esquerdo).
public struct Joint: Codable, Sendable, Equatable {
    public var x: Double
    public var y: Double
    public var confidence: Double

    public init(x: Double, y: Double, confidence: Double) {
        self.x = x
        self.y = y
        self.confidence = confidence
    }
}

public struct Point2D: Sendable, Equatable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct Skeleton: Sendable, Equatable {
    public var joints: [JointName: Joint]

    public init(joints: [JointName: Joint]) {
        self.joints = joints
    }

    /// Pares de juntas ligados por "ossos" (para desenhar).
    public static let bones: [(JointName, JointName)] = [
        (.leftShoulder, .rightShoulder), (.leftHip, .rightHip),
        (.leftShoulder, .leftHip), (.rightShoulder, .rightHip),
        (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist),
        (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist),
        (.leftHip, .leftKnee), (.leftKnee, .leftAnkle),
        (.rightHip, .rightKnee), (.rightKnee, .rightAnkle)
    ]

    /// Média das juntas indicadas cuja confiança é pelo menos `minConfidence`.
    public func midpoint(of names: [JointName], minConfidence: Double) -> Point2D? {
        let valid = names.compactMap { joints[$0] }.filter { $0.confidence >= minConfidence }
        guard !valid.isEmpty else { return nil }
        let count = Double(valid.count)
        return Point2D(x: valid.map(\.x).reduce(0, +) / count, y: valid.map(\.y).reduce(0, +) / count)
    }

    /// Centro usado pelo Tracker: quadris, senão ombros, senão qualquer junta com alguma confiança.
    public var centroid: Point2D? {
        midpoint(of: [.leftHip, .rightHip], minConfidence: 0.1)
            ?? midpoint(of: [.leftShoulder, .rightShoulder], minConfidence: 0.1)
            ?? midpoint(of: JointName.allCases, minConfidence: 0.1)
    }
}

extension Skeleton: Codable {
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode([String: Joint].self)
        var joints: [JointName: Joint] = [:]
        for (key, value) in raw {
            if let name = JointName(rawValue: key) { joints[name] = value }
        }
        self.joints = joints
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(Dictionary(uniqueKeysWithValues: joints.map { ($0.key.rawValue, $0.value) }))
    }
}
