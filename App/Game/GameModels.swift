import AganhaCore
import AganhaVision

struct GameSettings: Equatable {
    var difficulty: Difficulty = .sapeca
    var tolerance: Tolerance = .normal
    var commandSet: CommandSet = .classic
    var askNames = true
    /// Treino com um único jogador.
    var solo = false
    /// Eliminação (padrão) ou pontuação por rapidez, e quantas rodadas tem a partida de pontuação.
    var mode: GameMode = .elimination
    var scoreRounds = 10
    /// Erros que cada jogador pode cometer antes de sair.
    var maxErrors = 1
    /// Replay em vídeo da rodada (gravado só por alguns segundos e apagado em seguida).
    var recordReplay = true
    /// Atraso da TV espelhada por um app (s); os prazos de reação começam depois dele.
    var tvDelay = 0.0
}

/// Orientação falada e escrita na tela Posicionar.
struct Guidance: Equatable {
    let clip: String
    let text: String
    let slot: ChildSlot?
}

/// O que a tela "Alguém errou" mostra depois de uma rodada.
struct ResultInfo: Equatable {
    let result: RoundResult
    /// Até 3 quadros de esqueleto por criança eliminada.
    let replays: [ChildSlot: [Skeleton]]
    let continueAt: Double
    let duration: Double
    /// Mostra os botões "Foi injusto!" e "Continuar".
    let isManual: Bool
}
