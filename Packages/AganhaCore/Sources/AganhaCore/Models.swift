/// Postura de uma criança, produzida pela visão e consumida pelo jogo.
public enum Posture: String, Codable, Sendable, Equatable {
    case standing
    case crouching
    case unknown
}

/// Índice da vaga (0...5) atribuída a uma criança na tela "Posicionar".
public typealias ChildSlot = Int

public enum GameLimits {
    public static let maxChildren = 6
}

/// Única informação que o jogo recebe da visão: postura por vaga num instante.
public struct PostureSample: Sendable, Equatable {
    public let childSlot: ChildSlot
    public let posture: Posture
    public let timestamp: Double

    public init(childSlot: ChildSlot, posture: Posture, timestamp: Double) {
        self.childSlot = childSlot
        self.posture = posture
        self.timestamp = timestamp
    }
}
