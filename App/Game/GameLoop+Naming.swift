import AganhaAudio
import AganhaCore
import AganhaVision
import Foundation

/// Perguntar e guardar o nome de cada jogador (reconhecimento de fala só no aparelho).
extension GameLoop {
    // MARK: - Nomes

    func name(for slot: ChildSlot) -> String { names[slot] ?? SlotColors.displayName(slot) }

    /// Texto grande do topo da tela Posicionar, conforme o momento.
    var bannerText: String {
        switch step {
        case .framing:
            return guidance?.text ?? String(localized: "Procurando vocês…")
        case .naming:
            guard let slot = namingSlot else { return String(localized: "Vou conhecer vocês!") }
            let question = String(localized: "\(SlotColors.displayName(slot)), qual é o seu nome?")
            if isListening { return question + "\n🎤 " + (heardText.isEmpty ? String(localized: "Ouvindo…") : heardText) }
            return question
        case .ready:
            return namingNotice ?? String(localized: "Levantem os dois braços para começar!")
        }
    }

    var bannerSlot: ChildSlot? { step == .naming ? namingSlot : guidance?.slot }

    /// Define (ou corrige) o nome de uma vaga e lembra dele para as próximas partidas.
    func setName(_ raw: String, for slot: ChildSlot) {
        guard let clean = NameParser.clean(raw) else { return }
        names[slot] = clean
        recentNames = RecentNames.adding(clean, to: recentNames)
        UserDefaults.standard.set(recentNames, forKey: Self.recentNamesKey)
    }

    /// Atalho: usa um nome já conhecido para quem está sendo perguntado, sem falar.
    func useRecentName(_ name: String) {
        guard step == .naming, let slot = namingSlot else { return }
        namingTask?.cancel()
        audio.stop()
        setName(name, for: slot)
        resumeNaming()
    }

    func skipNaming() {
        guard step == .naming else { return }
        namingTask?.cancel()
        audio.stop()
        finishNaming()
    }

    func advanceToNames(_ report: PositioningReport, at time: Double) {
        guard settings.askNames, report.allReady else {
            readySince = nil
            return
        }
        let since = readySince ?? time
        readySince = since
        if time - since >= 2.0 { beginNaming() }
    }

    private func beginNaming() {
        guard step == .framing else { return }
        step = .naming
        promptTask?.cancel()
        audio.stop()
        namingNotice = nil
        let pending = report.people.map(\.slot).filter { names[$0] == nil }
        namingTask = Task { await runNaming(pending, introduce: true) }
    }

    private func resumeNaming() {
        let pending = report.people.map(\.slot).filter { names[$0] == nil }
        namingTask = Task { await runNaming(pending, introduce: false) }
    }

    private func runNaming(_ slots: [ChildSlot], introduce: Bool) async {
        if introduce, !slots.isEmpty {
            await audio.play("names_intro", fallbackText: "Vou conhecer vocês! Quando eu chamar, digam o seu nome.")
        }
        for slot in slots {
            guard !Task.isCancelled else { return }
            guard await askName(slot) else { break }
        }
        guard !Task.isCancelled else { return }
        finishNaming()
    }

    private func finishNaming() {
        namingSlot = nil
        isListening = false
        step = .ready
        namingTask = Task {
            await audio.play("setup_comecar_bracos", fallbackText: "Para começar, levantem os dois braços!")
        }
    }

    /// Pergunta o nome de uma vaga e escuta (no aparelho). Devolve false se a voz não está disponível.
    private func askName(_ slot: ChildSlot) async -> Bool {
        namingSlot = slot
        heardText = ""
        for attempt in 0..<2 {
            if attempt == 0 {
                await audio.play("names_pergunta", fallbackText: "\(SlotColors.displayName(slot)), qual é o seu nome?")
            } else {
                await audio.play("names_repetir", fallbackText: "Não entendi. Pode repetir o seu nome?")
            }
            guard !Task.isCancelled else { return true }
            isListening = true
            defer { isListening = false }
            do {
                let heard = try await listener.listen { self.heardText = $0 }
                guard !Task.isCancelled else { return true }
                if let name = NameParser.clean(heard) {
                    setName(name, for: slot)
                    await audio.speak("Prazer, \(name)!")
                    return true
                }
            } catch {
                logger.error("Escuta de nome indisponível: \(String(describing: error), privacy: .public)")
                namingNotice = String(localized: "Não consegui ouvir. Toque num nome para digitar, ou levantem os braços para começar.")
                return false
            }
        }
        return true
    }
}
