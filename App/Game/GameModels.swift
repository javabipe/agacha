import AganhaCore
import AganhaVision
import Foundation

struct GameSettings: Equatable, Codable {
    private static let storageKey = "settings.v1"

    var difficulty: Difficulty = .sapeca
    var tolerance: Tolerance = .normal
    var commandSet: CommandSet = .classic
    var askNames = true
    /// Quem aparece apresentando o jogo (a voz gravada ainda é só a da tia).
    var host: HostStyle = .tia
    /// Treino com um único jogador.
    var solo = false
    /// Eliminação (padrão) ou pontuação por rapidez, e quantas rodadas tem a partida de pontuação.
    var mode: GameMode = .score
    var scoreRounds = 10
    /// Comandos duplos ("Vivo! Morto!") quando o ritmo sobe.
    var doubles = true
    /// Erros que cada jogador pode cometer antes de sair.
    var maxErrors = 1
    /// Replay em vídeo da rodada (gravado só por alguns segundos e apagado em seguida).
    var recordReplay = true
    /// Atraso da TV espelhada por um app (s); os prazos de reação começam depois dele.
    var tvDelay = 0.0

    /// Lê os ajustes da última vez; na primeira vez, os padrões (pontuação, Sapeca, 10 rodadas).
    static func load() -> GameSettings {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode(GameSettings.self, from: data) else { return GameSettings() }
        return saved
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) { UserDefaults.standard.set(data, forKey: Self.storageKey) }
    }
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
