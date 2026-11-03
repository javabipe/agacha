public struct GameConfig: Sendable, Equatable {
    public var slots: [ChildSlot]
    public var difficulty: Difficulty
    public var tolerance: Tolerance
    public var commandSet: CommandSet
    public var seed: UInt64
    /// Quantos comandos seguidos "ausente" até a criança ser eliminada (saiu da câmera).
    public var maxAbsentStreak: Int
    public var rules: JudgeRules
    /// Quantos erros cada jogador pode cometer; ao chegar neste número, sai da partida.
    public var maxErrors: Int
    /// Atraso (s) entre o iPad e o que os jogadores veem/ouvem (TV espelhada por um app). Adia a janela de julgamento.
    public var displayDelay: Double
    /// Treino com um único jogador: a partida acaba quando ele atinge o limite de erros.
    public var solo: Bool
    /// Eliminação (padrão) ou pontuação por rapidez.
    public var mode: GameMode
    /// Rodadas da partida no modo pontuação.
    public var scoreRounds: Int
    public var scoreRules: ScoreRules

    public init(slots: [ChildSlot], difficulty: Difficulty = .sapeca, tolerance: Tolerance = .normal,
                commandSet: CommandSet = .classic, seed: UInt64, maxAbsentStreak: Int = 3,
                rules: JudgeRules = JudgeRules(), maxErrors: Int = 1, displayDelay: Double = 0, solo: Bool = false,
                mode: GameMode = .elimination, scoreRounds: Int = 10, scoreRules: ScoreRules = ScoreRules()) {
        self.slots = slots
        self.difficulty = difficulty
        self.tolerance = tolerance
        self.commandSet = commandSet
        self.seed = seed
        self.maxAbsentStreak = maxAbsentStreak
        self.rules = rules
        self.maxErrors = max(1, maxErrors)
        self.displayDelay = min(max(0, displayDelay), 10)
        self.solo = solo
        self.mode = mode
        self.scoreRounds = min(max(1, scoreRounds), 50)
        self.scoreRules = scoreRules
    }
}

public struct PlayerState: Sendable, Equatable {
    public var isEliminated = false
    /// Número do comando em que foi eliminada.
    public var eliminatedAt: Int?
    public var correct = 0
    /// Erros cometidos até agora (a partida elimina ao chegar em `maxErrors`).
    public var errors = 0
    public var points = 0
    public var absentStreak = 0
    /// Modo pontuação: moedas, acertos seguidos e tempos de reação.
    public var coins = 0
    public var combo = 0
    public var bestCombo = 0
    public var reactionTotalMs = 0
    public var reactionCount = 0
    public var bestReactionMs: Int?

    public var averageReactionMs: Int? { reactionCount == 0 ? nil : reactionTotalMs / reactionCount }

    public init() {}
}

public struct GameResult: Sendable, Equatable {
    /// Mais de um vencedor = empate.
    public let winners: [ChildSlot]
    /// Do melhor para o pior (quem caiu por último fica na frente).
    public let ranking: [ChildSlot]

    public var isTie: Bool { winners.count > 1 }
}

public struct RoundResult: Sendable, Equatable {
    public let command: Command
    public let verdicts: [ChildSlot: Verdict]
    /// O que o juiz mediu de cada um (índice de agachamento, postura).
    public let details: [ChildSlot: Judge.Assessment]
    /// Quem errou nesta rodada (pode continuar na partida se ainda tiver erros sobrando).
    public let wrong: [ChildSlot]
    public let eliminated: [ChildSlot]
    public let survivors: [ChildSlot]
    /// Todos que restavam erraram juntos: ninguém sai e a partida termina empatada.
    public let isTie: Bool
    /// Preenchido quando esta rodada encerra a partida.
    public let finished: GameResult?
    /// Modo pontuação: o que cada jogador ganhou nesta rodada (vazio na eliminação).
    public var scores: [ChildSlot: RoundScore] = [:]
}

public enum GamePhase: Sendable, Equatable {
    case lobby
    case countdown
    /// Comando escolhido, esperando o áudio começar.
    case announcing(Command)
    case window(Command, opensAt: Double, closesAt: Double)
    case result(RoundResult)
    case gameOver(GameResult)
}

public enum GameAction: Sendable {
    case start(GameConfig)
    case countdownFinished
    case commandAudioStarted(at: Double)
    case postureSamples([PostureSample])
    case windowClosed
    /// Botão "Foi injusto!": desfaz a rodada e sorteia outro comando, sem eliminar ninguém.
    case unfair
    /// "Continuar" depois do resultado.
    case next
    case quit
}

/// Pedidos que o reducer faz ao GameLoop (áudio, relógio, UI).
public enum GameEffect: Sendable, Equatable {
    case startCountdown
    case playCommand(Command)
    case scheduleWindowClose(at: Double)
    case showResult(RoundResult)
    case finished(GameResult)
}

public struct GameState: Sendable, Equatable {
    public internal(set) var phase: GamePhase = .lobby
    public internal(set) var config: GameConfig?
    public internal(set) var players: [ChildSlot: PlayerState] = [:]
    /// Comandos já emitidos nesta partida.
    public internal(set) var round = 0
    public internal(set) var history: [RoundResult] = []

    var director: Director?
    var samples: [ChildSlot: [PostureSample]] = [:]
    /// Jogadores antes do julgamento da rodada atual (para "Foi injusto!").
    var snapshot: [ChildSlot: PlayerState] = [:]
    /// Diretor antes de sortear o comando atual ("Foi injusto!" repete o mesmo comando, sem pular a numeração).
    var directorSnapshot: Director?

    public init() {}

    public var survivors: [ChildSlot] {
        players.filter { !$0.value.isEliminated }.map(\.key).sorted()
    }
}
