import AganhaAudio
import AganhaCore

/// Voz depois de cada rodada e no fim da partida (os jogadores são chamados pelo nome).
extension GameLoop {
    func playFeedback(for result: RoundResult) async {
        if result.isTie {
            await audio.speak(String(localized: "Todos erraram juntos!"))
            return
        }
        for slot in result.eliminated {
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
        }
    }
}
