import AganhaAudio
import AganhaCore

/// Voz depois de cada rodada e no fim da partida (os jogadores são chamados pelo nome).
extension GameLoop {
    func playFeedback(for result: RoundResult) async {
        if result.isTie {
            await audio.speak(String(localized: "Todos erraram juntos!"))
            return
        }
        for slot in result.wrong {
            await audio.speak("\(name(for: slot)) errou!")
            if Task.isCancelled { return }
        }
        if result.finished == nil, !result.eliminated.isEmpty, result.survivors.count == 2 {
            await audio.play("fb_restam_dois", fallbackText: "Só restam dois! É a final!")
        }
    }

    func celebrate(_ result: GameResult) {
        gameTask = Task {
            if let winner = result.winners.first, !result.isTie {
                await audio.speak("\(name(for: winner)) venceu! Parabéns!")
                guard !Task.isCancelled else { return }
                await audio.play("fb_campeao", fallbackText: "Temos um campeão! Parabéns!")
            } else {
                let who = result.winners.map { name(for: $0) }.joined(separator: " e ")
                await audio.speak("Deu empate entre \(who)!")
                guard !Task.isCancelled else { return }
                await audio.play("fb_fim_de_jogo", fallbackText: "Fim de jogo!")
            }
            guard !Task.isCancelled else { return }
            startGameOverControls()
        }
    }

    /// ✕ para quem saiu; corações restantes quando a partida permite mais de um erro.
    func statusDetail(for slot: ChildSlot) -> String? {
        guard let player = state.players[slot] else { return nil }
        if player.isEliminated { return "✕" }
        let limit = state.config?.maxErrors ?? 1
        guard limit > 1 else { return nil }
        return String(repeating: "♥", count: max(0, limit - player.errors)) + String(repeating: "♡", count: player.errors)
    }
}
