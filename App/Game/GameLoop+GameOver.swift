import AganhaAudio
import AganhaCore
import AganhaVision
import Foundation

/// Fim de partida sem tocar na tela: dizer "de novo" (ou "menu") ou levantar os dois braços.
extension GameLoop {
    /// Quanto tempo os braços ficam para cima para valer como "de novo".
    static let playAgainHold = 0.8

    func startGameOverControls() {
        guard case .gameOver = state.phase else { return }
        gameOverTask?.cancel()
        gameOverTask = Task {
            await audio.speak("Vamos jogar de novo? Diga: de novo! Ou levante os dois braços. Para sair, diga: menu.")
            while !Task.isCancelled {
                guard case .gameOver = state.phase else { return }
                isListening = true
                heardText = ""
                defer { isListening = false }
                do {
                    let heard = try await listener.listen(maxDuration: 6, silence: 1.0) { self.heardText = $0 }
                    guard !Task.isCancelled else { return }
                    switch VoiceIntent.parse(heard) {
                    case .playAgain:
                        playAgain()
                        return
                    case .menu:
                        wantsMenu = true
                        return
                    case nil:
                        try? await Task.sleep(for: .milliseconds(300))
                    }
                } catch {
                    // Sem voz (permissão ou serviço indisponível): ficam os botões e o gesto de braços.
                    logger.error("Comando de voz indisponível: \(String(describing: error), privacy: .public)")
                    return
                }
            }
        }
    }

    func playAgain() {
        gameOverTask?.cancel()
        playAgainSince = nil
        startPositioning(keepSlots: true)
    }

    /// Os dois braços para cima por um instante, por qualquer jogador, começam outra partida.
    func checkPlayAgainGesture(_ analysis: FrameAnalysis) {
        let raising = PositioningCheck.evaluate(analysis).people.contains(where: \.raisingBothArms)
        guard raising else {
            playAgainSince = nil
            return
        }
        let since = playAgainSince ?? analysis.timestamp
        playAgainSince = since
        if analysis.timestamp - since >= Self.playAgainHold { playAgain() }
    }
}
