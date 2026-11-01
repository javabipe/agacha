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

/// O que o comando manda fazer (ou o gesto da tia mostra): de pé ou agachado.
public enum Stance: String, Codable, Sendable, Equatable {
    case up
    case down

    public var opposite: Stance { self == .up ? .down : .up }

    /// Postura que a criança precisa estar para cumprir este comando.
    public var posture: Posture { self == .up ? .standing : .crouching }
}

public enum Difficulty: String, Codable, Sendable, CaseIterable {
    case tranquilo
    case sapeca
    case furacao
}

/// Folga na hora de julgar (quanto tempo a criança tem para reagir).
public enum Tolerance: String, Codable, Sendable, CaseIterable {
    case pequenos
    case normal
    case rigido

    public var windowMs: Int {
        switch self {
        case .pequenos: 1100
        case .normal: 800
        case .rigido: 500
        }
    }
}

/// Palavras usadas nos comandos. O áudio de cada palavra é identificado por `audioID`.
public enum CommandSet: String, Codable, Sendable, CaseIterable {
    case classic
    case school
    case en

    public func text(for stance: Stance) -> String {
        switch (self, stance) {
        case (.classic, .up): "VIVO!"
        case (.classic, .down): "MORTO!"
        case (.school, .up): "LEVANTA!"
        case (.school, .down): "AGACHA!"
        case (.en, .up): "UP!"
        case (.en, .down): "DOWN!"
        }
    }

    /// Trecho do nome do clipe de áudio (`<voz>_cmd_<audioID>_v<n>`).
    public func audioID(for stance: Stance) -> String {
        switch (self, stance) {
        case (.classic, .up): "vivo"
        case (.classic, .down): "morto"
        case (.school, .up): "levanta"
        case (.school, .down): "agacha"
        case (.en, .up): "up"
        case (.en, .down): "down"
        }
    }

    /// Cor de fundo da palavra: verde-água para "em pé", coral para "agachar".
    public func colorHex(for stance: Stance) -> String {
        stance == .up ? "#1FA98A" : "#E0523C"
    }
}

/// Um comando da tia. A palavra falada (`word`) é o que vale para o julgamento;
/// o gesto (`gesture`) pode ser o contrário, e então é um truque.
public struct Command: Sendable, Equatable {
    /// Posição do comando na partida (1 = primeiro).
    public let number: Int
    public let word: Stance
    public let gesture: Stance
    /// Mesma palavra do comando anterior ("fica").
    public let isRepeat: Bool
    /// Intervalo em ms entre o fim da janela deste comando e o início do áudio do próximo.
    public let gapMs: Int
    /// O próximo comando vem "emendado" (intervalo mínimo). Só no Furacão.
    public let chainsToNext: Bool
    public let windowMs: Int

    public var isTrick: Bool { word != gesture }

    public init(number: Int, word: Stance, gesture: Stance, isRepeat: Bool, gapMs: Int,
                chainsToNext: Bool, windowMs: Int) {
        self.number = number
        self.word = word
        self.gesture = gesture
        self.isRepeat = isRepeat
        self.gapMs = gapMs
        self.chainsToNext = chainsToNext
        self.windowMs = windowMs
    }
}

/// Resultado do julgamento de uma criança em um comando.
public enum Verdict: String, Codable, Sendable, Equatable {
    case ok
    case wrong
    /// Não foi vista (ou postura desconhecida) no fim da janela. Não elimina de imediato.
    case absent
}
