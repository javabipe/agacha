import AganhaCore
import AganhaVision

struct GameSettings: Equatable {
    var difficulty: Difficulty = .sapeca
    var tolerance: Tolerance = .normal
    var commandSet: CommandSet = .classic
    var askNames = true
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
