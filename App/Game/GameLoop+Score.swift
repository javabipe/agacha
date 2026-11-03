import AganhaAudio
import AganhaCore
import Foundation

/// Modo pontuação: ninguém sai; cada acerto vira moedas pela rapidez e a partida acaba depois de N rodadas.
extension GameLoop {
    var isScoreMode: Bool { state.config?.mode == .score }

    /// Rodada do modo pontuação: sem tela de erro nem replay; o resultado aparece como efeito (iPad e TV)
    /// enquanto o ritmo do nível segue. No fim da partida, espera um pouco para ver as últimas moedas.
    func showScoreResult(_ result: RoundResult) {
        shownCommand = nil
        let delay = result.finished == nil ? Double(result.command.gapMs) / 1000 : 3.0
        let deadline = Self.now() + delay
        resultTask = Task {
            let remaining = deadline - Self.now()
            if remaining > 0 { try? await Task.sleep(for: .seconds(remaining)) }
            guard !Task.isCancelled else { return }
            send(.next)
        }
    }

    /// Último resultado de cada jogador (para o iPad e a TV mostrarem o que acabou de acontecer).
    func lastScore(for slot: ChildSlot) -> RoundScore? {
        state.history.last?.scores[slot]
    }

    /// Placar do fim da partida, do primeiro ao último.
    func scoreLines(for result: GameResult) -> [ScoreLine] {
        result.ranking.compactMap { slot in
            guard let player = state.players[slot] else { return nil }
            return ScoreLine(slot: slot, coins: player.coins, averageMs: player.averageReactionMs,
                             bestMs: player.bestReactionMs, bestCombo: player.bestCombo)
        }
    }

    /// Melhor resultado do treino solo no modo pontuação (por nível e número de rodadas): moedas.
    func recordSoloCoins() {
        guard let config = state.config, config.solo, let slot = config.slots.first, let player = state.players[slot] else { return }
        let key = "soloBestCoins.\(config.difficulty.rawValue).\(config.scoreRounds)"
        let previous = UserDefaults.standard.integer(forKey: key)
        soloScore = player.coins
        soloIsRecord = player.coins > previous
        soloBest = max(player.coins, previous)
        if soloIsRecord { UserDefaults.standard.set(player.coins, forKey: key) }
    }

    /// Resumo do treino solo (acertos no modo eliminação; moedas e tempos no modo pontuação).
    var soloSummary: SoloSummary {
        let player = state.config?.slots.first.flatMap { state.players[$0] }
        return SoloSummary(score: soloScore, best: soloBest, isRecord: soloIsRecord, isScore: isScoreMode,
                           averageMs: player?.averageReactionMs, bestMs: player?.bestReactionMs, bestCombo: player?.bestCombo ?? 0)
    }

    /// Fala a reação média, "0,6 segundos".
    static func spokenSeconds(_ ms: Int) -> String {
        (Double(ms) / 1000).formatted(.number.precision(.fractionLength(1)))
    }
}

/// Uma linha do placar final do modo pontuação.
struct ScoreLine: Equatable {
    let slot: ChildSlot
    let coins: Int
    let averageMs: Int?
    let bestMs: Int?
    let bestCombo: Int
}
