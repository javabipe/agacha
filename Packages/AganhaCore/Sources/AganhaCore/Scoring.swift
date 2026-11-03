/// Como a partida termina e quem ganha.
public enum GameMode: String, Codable, Sendable, CaseIterable {
    /// Errou, sai (ou perde uma vida); o último que fica vence.
    case elimination
    /// Ninguém sai: cada acerto vale moedas pela rapidez e vence quem juntar mais depois de N rodadas.
    case score
}

/// Faixa de rapidez de um acerto no modo pontuação.
public enum ScoreTier: String, Codable, Sendable, Equatable {
    case perfect
    case great
    case good
    /// Já estava na postura certa quando a janela abriu (comando repetido): vale pouco e não tem tempo de reação.
    case held
    case miss
}

/// Tempos e moedas do modo pontuação. Os tempos contam do início do comando que os jogadores veem/ouvem.
public struct ScoreRules: Sendable, Equatable {
    public var perfectMs = 900
    public var greatMs = 1300
    /// Quem estava agachado e precisa levantar ganha este tempo a mais em cada faixa (subir demora mais que descer).
    public var riseExtraMs = 300
    public var perfectCoins = 5
    public var greatCoins = 3
    public var goodCoins = 1
    public var heldCoins = 2
    /// A cada tantos acertos seguidos o multiplicador sobe 1 (x2, x3...), até `maxMultiplier`.
    public var comboStep = 3
    public var maxMultiplier = 4

    public init() {}

    public func tier(reactionMs: Int, rising: Bool) -> ScoreTier {
        let extra = rising ? riseExtraMs : 0
        if reactionMs <= perfectMs + extra { return .perfect }
        if reactionMs <= greatMs + extra { return .great }
        return .good
    }

    public func baseCoins(for tier: ScoreTier) -> Int {
        switch tier {
        case .perfect: perfectCoins
        case .great: greatCoins
        case .good: goodCoins
        case .held: heldCoins
        case .miss: 0
        }
    }

    /// `combo` já conta o acerto atual (o 3º acerto seguido já vale x2).
    public func multiplier(forCombo combo: Int) -> Int {
        min(maxMultiplier, 1 + max(0, combo) / max(1, comboStep))
    }
}

/// O que um jogador ganhou numa rodada do modo pontuação.
public struct RoundScore: Sendable, Equatable {
    public let tier: ScoreTier
    /// Tempo de reação em ms (nil se errou ou se já estava na postura certa).
    public let reactionMs: Int?
    /// Moedas já com o multiplicador.
    public let coins: Int
    public let multiplier: Int
    /// Acertos seguidos até aqui (0 se errou).
    public let combo: Int
    /// Comando duplo: as moedas somam as duas palavras.
    public var isDouble = false
}
