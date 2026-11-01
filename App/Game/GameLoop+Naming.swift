import AganhaAudio
import AganhaCore
import AganhaVision
import Foundation

/// Nomes dos jogadores: texto da tela, escolha por voz (ou digitada) e vagas sem jogador apresentado.
extension GameLoop {
    // MARK: - Texto do topo da tela Posicionar

    var bannerText: String {
        switch step {
        case .meeting:
            var text = meetingPrompt.isEmpty ? String(localized: "Vamos conhecer vocês!") : meetingPrompt
            if isListening {
                text += "\n🎤 " + (heardText.isEmpty ? String(localized: "Ouvindo…") : heardText)
            } else if let faceHint {
                text += "\n" + faceHint
            }
            return text
        case .placing:
            return String(localized: "Agora coloque o aparelho em pé, encostado no chão e apoiado na parede.")
        case .identifying:
            return String(localized: "Reconhecendo cada um…")
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

    var bannerSlot: ChildSlot? {
        switch step {
        case .naming: namingSlot
        case .framing: guidance?.slot
        default: nil
        }
    }

    func name(for slot: ChildSlot) -> String { names[slot] ?? SlotColors.displayName(slot) }

    // MARK: - Nomes

    /// Define (ou corrige) o nome de uma vaga e lembra dele para as próximas partidas.
    func setName(_ raw: String, for slot: ChildSlot) {
        guard let clean = NameParser.clean(raw) else { return }
        names[slot] = clean
        remember(clean)
        if let id = slotPlayers[slot] { profileStore.rename(id, to: clean) }
    }

    func remember(_ name: String) {
        recentNames = RecentNames.adding(name, to: recentNames)
        UserDefaults.standard.set(recentNames, forKey: Self.recentNamesKey)
    }

    /// Atalho: usa um nome já conhecido para quem está sendo perguntado, sem precisar falar.
    func useRecentName(_ name: String) {
        guard awaitingName else { return }
        quickName = name
        listenTask?.cancel()
        audio.stop()
        resolveTyping(name)
    }

    func skipNaming() {
        guard step == .naming else { return }
        namingTask?.cancel()
        listenTask?.cancel()
        resolveTyping(nil)
        audio.stop()
        awaitingName = false
        finishNaming()
    }

    // MARK: - Vagas sem jogador apresentado

    func advanceWhenReady(_ report: PositioningReport, at time: Double) {
        guard settings.askNames, report.allReady else {
            readySince = nil
            return
        }
        let since = readySince ?? time
        readySince = since
        guard time - since >= 2.0 else { return }
        if met.isEmpty { beginNaming() } else { beginIdentifying() }
    }

    func collectAppearance(_ analysis: FrameAnalysis) {
        for person in analysis.people {
            guard let slot = person.slot, let signature = person.appearance else { continue }
            slotSignatures[slot, default: []].append(signature)
        }
    }

    /// Liga cada vaga ao jogador apresentado pela cor da roupa; quem sobrar é perguntado pelo nome.
    private func beginIdentifying() {
        guard step == .framing else { return }
        step = .identifying
        slotSignatures = [:]
        promptTask?.cancel()
        audio.stop()
        namingTask = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            let seen = slotSignatures.compactMapValues { AppearanceSignature.average($0) }
            let players = Dictionary(uniqueKeysWithValues: met.compactMap { player in
                player.clothing.map { (player.id.uuidString, $0) }
            })
            for (slot, id) in AppearanceMatcher.assign(slots: seen, players: players) {
                guard let player = met.first(where: { $0.id.uuidString == id }) else { continue }
                names[slot] = player.name
                slotPlayers[slot] = player.id
            }
            let pending = report.people.map(\.slot).filter { names[$0] == nil }
            if pending.isEmpty {
                let who = report.people.map { name(for: $0.slot) }
                await audio.speak("Prontos, \(Self.joined(who))!")
                guard !Task.isCancelled else { return }
                finishNaming()
            } else {
                step = .naming
                await runNaming(pending)
            }
        }
    }

    func beginNaming() {
        guard step == .framing else { return }
        step = .naming
        promptTask?.cancel()
        audio.stop()
        namingNotice = nil
        let pending = report.people.map(\.slot).filter { names[$0] == nil }
        namingTask = Task { await runNaming(pending) }
    }

    private func runNaming(_ slots: [ChildSlot]) async {
        for slot in slots {
            guard !Task.isCancelled else { return }
            namingSlot = slot
            heardText = ""
            let color = SlotColors.displayName(slot)
            let name = await obtainName(prompt: "\(color), qual é o seu nome?", clip: "names_pergunta",
                                        typingTitle: "Nome de \(color)")
            guard !Task.isCancelled else { return }
            if let name {
                setName(name, for: slot)
                await audio.speak("Prazer, \(self.name(for: slot))!")
            }
        }
        guard !Task.isCancelled else { return }
        finishNaming()
    }

    func finishNaming() {
        namingSlot = nil
        isListening = false
        step = .ready
        namingTask = Task {
            await audio.play("setup_comecar_bracos", fallbackText: "Para começar, levantem os dois braços!")
        }
    }

    // MARK: - Pergunta de nome (voz ou digitado)

    /// Pergunta o nome e escuta. Se a voz não ajudar (sem permissão, não entendeu duas vezes), um adulto digita.
    /// Devolve nil se a pessoa cancelar.
    func obtainName(prompt: String, clip: String?, typingTitle: String) async -> String? {
        quickName = nil
        awaitingName = true
        defer { awaitingName = false }
        meetingPrompt = prompt
        for attempt in 0..<2 {
            let spoken = attempt == 0 ? prompt : "Não entendi. Pode repetir o seu nome?"
            if let clip, attempt == 0 {
                await audio.play(clip, fallbackText: spoken)
            } else {
                await audio.speak(spoken)
            }
            if let quick = quickName { return quick }
            guard !Task.isCancelled else { return nil }
            isListening = true
            heardText = ""
            defer { isListening = false }
            do {
                let heard = try await listen()
                if let quick = quickName { return quick }
                guard !Task.isCancelled else { return nil }
                if let name = NameParser.clean(heard) { return name }
            } catch is CancellationError {
                if let quick = quickName { return quick }
                return nil
            } catch {
                logger.error("Escuta de nome indisponível: \(String(describing: error), privacy: .public)")
                namingNotice = Self.message(for: error)
                break
            }
        }
        isListening = false
        return await requestTypedName(title: typingTitle)
    }

    private func listen() async throws -> String {
        let task = Task { try await listener.listen { self.heardText = $0 } }
        listenTask = task
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }

    func requestTypedName(title: String) async -> String? {
        guard !Task.isCancelled else { return nil }
        return await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<String?, Never>) in
                typingContinuation = continuation
                typingRequest = TypingRequest(title: title)
            }
        } onCancel: {
            Task { @MainActor in self.resolveTyping(nil) }
        }
    }

    /// Resposta do alerta de digitação (nil = cancelou).
    func resolveTyping(_ text: String?) {
        typingRequest = nil
        let continuation = typingContinuation
        typingContinuation = nil
        continuation?.resume(returning: NameParser.clean(text ?? ""))
    }

    static func joined(_ names: [String]) -> String {
        switch names.count {
        case 0: ""
        case 1: names[0]
        default: names.dropLast().joined(separator: ", ") + " e " + names[names.count - 1]
        }
    }

    private static func message(for error: Error) -> String {
        switch error as? NameListener.Unavailable {
        case .speechPermissionDenied:
            String(localized: "Sem permissão de reconhecimento de fala (Ajustes › Agacha).")
        case .microphonePermissionDenied:
            String(localized: "Sem permissão de microfone (Ajustes › Agacha).")
        case .recognizerUnavailable:
            String(localized: "O reconhecimento de fala não está disponível agora.")
        case nil:
            String(localized: "Não consegui usar o microfone.")
        }
    }
}
