import AganhaAudio
import Foundation

struct CountdownStep {
    let clip: String
    let text: String
    let label: String
}

/// Contagem falada ("Preparados? 3, 2, 1, Já!"), no início da partida e depois de cada replay.
extension GameLoop {
    static let readySteps: [CountdownStep] = [
        CountdownStep(clip: "flow_preparados", text: "Preparados?", label: String(localized: "Preparados?")),
        CountdownStep(clip: "flow_count_3", text: "Três!", label: "3"),
        CountdownStep(clip: "flow_count_2", text: "Dois!", label: "2"),
        CountdownStep(clip: "flow_count_1", text: "Um!", label: "1"),
        CountdownStep(clip: "flow_count_go", text: "Já!", label: String(localized: "JÁ!"))
    ]

    /// Fala cada passo, mostrando o texto na tela. `pauseAfter` roda depois do passo com esse clipe.
    func playCountdown(_ steps: [CountdownStep], pauseAfter: (String, () async -> Void)? = nil) async {
        for step in steps {
            countdownText = step.label
            await audio.play(step.clip, fallbackText: step.text)
            guard !Task.isCancelled else { return }
            if step.clip.hasPrefix("flow_count_") { try? await Task.sleep(for: .milliseconds(250)) }
            if let pauseAfter, pauseAfter.0 == step.clip { await pauseAfter.1() }
            guard !Task.isCancelled else { return }
        }
        countdownText = nil
    }

    /// Depois do replay os jogadores saíram do lugar: avisa para voltar e refaz a contagem.
    func playRestartCountdown() async {
        let back = CountdownStep(clip: "flow_voltem", text: "Voltem para o seu lugar!", label: String(localized: "Voltem ao lugar!"))
        await playCountdown([back] + Self.readySteps)
    }
}
