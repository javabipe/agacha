import AganhaAudio
import AganhaCore
import AganhaVision

/// Orientações do enquadramento (falar o que falta) e o gesto de braços para começar.
extension GameLoop {
    // MARK: - Posicionar

    func checkRaisedArms(_ report: PositioningReport, at time: Double) {
        let canStart = step == .ready || (!settings.askNames && step == .framing)
        guard canStart, report.allReady, report.anyRaisingBothArms else {
            handsUpSince = nil
            return
        }
        let since = handsUpSince ?? time
        handsUpSince = since
        if time - since >= Self.handsUpHold { startGame() }
    }

    func guidance(for report: PositioningReport) -> Guidance {
        func make(_ clip: String, _ text: String.LocalizationValue, slot: ChildSlot? = nil) -> Guidance {
            Guidance(clip: clip, text: String(localized: text), slot: slot)
        }
        if report.people.isEmpty {
            return make("setup_afastem", "Afastem-se até eu ver todo mundo, da cabeça aos pés.")
        }
        if let problem = report.firstProblem, let issue = problem.issue {
            switch issue {
            case .noHead: return make("setup_sem_cabeca", "Não estou vendo a cabeça de alguém.", slot: problem.slot)
            case .noFeet: return make("setup_sem_pes", "Não estou vendo os pés de alguém.", slot: problem.slot)
            case .cutOff: return make("setup_cortado", "Tem alguém cortado na imagem.", slot: problem.slot)
            }
        }
        if report.people.count < report.minPlayers {
            return make("setup_pouca_gente", "Preciso de pelo menos duas pessoas para brincar.")
        }
        if settings.askNames { return make("setup_pronto", "Pronto! Já vi todo mundo!") }
        return make("setup_comecar_bracos", "Prontos! Levantem os dois braços para começar.")
    }

    /// Só fala quando a orientação fica estável por um instante e não repete a mesma a cada quadro.
    func updateGuidance(_ report: PositioningReport) {
        let next = guidance(for: report)
        let time = Self.now()
        if next != candidate {
            candidate = next
            candidateSince = time
        }
        let stable = time - candidateSince
        if stable > 0.8, next != guidance { guidance = next }
        guard stable > 1.2, !audio.isPlaying, next != spoken || time - lastSpokenAt > 12 else { return }
        spoken = next
        lastSpokenAt = time
        promptTask = Task {
            await audio.play(next.clip, fallbackText: next.text)
            lastSpokenAt = Self.now()
        }
    }
}
