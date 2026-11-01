import AganhaAudio
import AganhaCore
import AganhaVision
import Foundation

/// "Vamos conhecer vocês": cada jogador mostra o rosto de perto, é reconhecido (ou apresentado pelo nome)
/// e só então o aparelho vai para o chão. Rostos ficam só no aparelho, com autorização de um adulto.
extension GameLoop {
    static let goodScansNeeded = 5

    func beginMeeting() {
        guard stage == .positioning, step == .meeting else { return }
        finishMeetingRequested = false
        rejectRequested = false
        placementConfirmed = false
        faceBuffer = []
        pipeline.mode = .faces
        pipeline.computeAppearance = false
        meetingTask = Task { await runMeeting() }
    }

    /// Botão "Pronto": ninguém mais para apresentar.
    func finishMeeting() {
        finishMeetingRequested = true
        listenTask?.cancel()
    }

    /// Botão "Não sou ...": o rosto foi confundido com outra pessoa.
    func rejectRecognition() {
        guard recognizedCandidate != nil else { return }
        rejectRequested = true
    }

    func confirmPlacement() {
        placementConfirmed = true
    }

    func answerConsent(_ granted: Bool) {
        consentRequest = false
        let continuation = consentContinuation
        consentContinuation = nil
        continuation?.resume(returning: granted)
    }

    // MARK: - Câmera de perto

    func observeFace(_ analysis: FrameAnalysis) {
        guard let face = analysis.face else {
            faceHint = String(localized: "Não estou vendo um rosto. Chegue perto da câmera.")
            return
        }
        if face.boundingBox.width < FaceScanner.minWidth {
            faceHint = String(localized: "Chegue um pouco mais perto.")
        } else if abs(face.yaw) > FaceScanner.maxYaw {
            faceHint = String(localized: "Olhe de frente para a câmera.")
        } else if face.quality < FaceScanner.minQuality {
            faceHint = String(localized: "Fique parado e com mais luz no rosto.")
        } else {
            faceHint = nil
        }
        if face.isGood, face.print != nil {
            faceBuffer.append((analysis.timestamp, face))
            if faceBuffer.count > 20 { faceBuffer.removeFirst() }
        }
    }

    // MARK: - Fluxo

    private func runMeeting() async {
        if profileStore.consent == nil {
            let granted = await askConsent()
            guard !Task.isCancelled else { return }
            profileStore.consent = granted
        }
        guard profileStore.consent == true else {
            await endMeeting(skipped: true)
            return
        }
        await say("Vamos conhecer vocês!", clip: "meet_intro")
        var first = true
        while !Task.isCancelled, !finishMeetingRequested, met.count < GameLimits.maxChildren {
            if first {
                await say("Quem é o primeiro? Chegue perto e mostre o seu rosto.", clip: "meet_first")
            } else {
                await say("Tem mais alguém? Mostre o rosto, ou toque em Pronto.", clip: "meet_more")
            }
            guard let capture = await captureNewFace(timeout: first ? nil : 12) else { break }
            await register(capture)
            first = false
        }
        guard !Task.isCancelled else { return }
        await endMeeting(skipped: false)
    }

    private func say(_ text: String, clip: String) async {
        meetingPrompt = text
        await audio.play(clip, fallbackText: text)
    }

    private func askConsent() async -> Bool {
        guard !Task.isCancelled else { return false }
        return await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                consentContinuation = continuation
                consentRequest = true
            }
        } onCancel: {
            Task { @MainActor in self.answerConsent(false) }
        }
    }

    /// Espera um rosto nítido e de frente (várias leituras seguidas). Ignora quem já foi apresentado.
    private func captureNewFace(timeout: Double?) async -> FaceCapture? {
        let started = Self.now()
        faceBuffer = []
        while !Task.isCancelled {
            if finishMeetingRequested { return nil }
            let now = Self.now()
            if let timeout, now - started > timeout { return nil }
            let recent = faceBuffer.filter { now - $0.time < 3 }
            faceProgress = min(1, Double(recent.count) / Double(Self.goodScansNeeded))
            if recent.count >= Self.goodScansNeeded {
                let capture = FaceCapture(prints: recent.compactMap(\.scan.print),
                                          clothing: AppearanceSignature.average(recent.compactMap(\.scan.clothing)))
                faceBuffer = []
                faceProgress = 0
                if !met.isEmpty,
                   case .match = profileStore.identify(capture.prints, among: Set(met.map(\.id))).decision {
                    faceHint = String(localized: "Já conheço você. Chame o próximo!")
                    continue
                }
                return capture
            }
            try? await Task.sleep(for: .milliseconds(100))
        }
        return nil
    }

    private func register(_ capture: FaceCapture) async {
        let result = profileStore.identify(capture.prints, excluding: Set(met.map(\.id)))
        recognitionDebug = result.debug
        guard case let .match(_, ratio) = result.decision, let profile = result.profile else {
            await registerNew(capture)
            return
        }
        let player = MetPlayer(id: profile.id, name: profile.name, clothing: capture.clothing, isNew: false)
        recognizedCandidate = player
        rejectRequested = false
        meetingPrompt = "Oi, \(profile.name)! Já conheço você."
        await audio.speak(meetingPrompt)
        // Uns segundos para corrigir ("Não sou ..."), antes de aprender com esta leitura.
        let deadline = Self.now() + 2.5
        while !Task.isCancelled, !rejectRequested, Self.now() < deadline {
            try? await Task.sleep(for: .milliseconds(100))
        }
        recognizedCandidate = nil
        guard !Task.isCancelled else { return }
        if rejectRequested {
            rejectRequested = false
            await registerNew(capture)
            return
        }
        if ratio <= 0.8 { profileStore.addSamples(capture.prints, to: profile.id) }
        met.append(player)
    }

    private func registerNew(_ capture: FaceCapture) async {
        if !met.isEmpty {
            let who = Self.joined(met.map(\.name))
            meetingPrompt = "Já conheço \(who), mas falta conhecer outro."
            await audio.speak(meetingPrompt)
        }
        let name = await obtainName(prompt: "Qual é o seu nome?", clip: "names_pergunta", typingTitle: "Nome do jogador")
        guard !Task.isCancelled else { return }
        let finalName = name ?? "Jogador \(met.count + 1)"
        let profile = profileStore.upsert(name: finalName, prints: capture.prints)
        met.append(MetPlayer(id: profile?.id ?? UUID(), name: finalName, clothing: capture.clothing, isNew: true))
        remember(finalName)
        await audio.speak("Prazer, \(finalName)!")
    }

    private func endMeeting(skipped: Bool) async {
        faceHint = nil
        faceProgress = 0
        pipeline.mode = .pose
        pipeline.requestReset()
        guard !skipped, !met.isEmpty else {
            step = .framing
            return
        }
        pipeline.computeAppearance = true
        placementConfirmed = false
        step = .placing
        await audio.play("meet_place", fallbackText: "Agora coloque o aparelho em pé, encostado no chão e apoiado na parede.")
        let deadline = Self.now() + 10
        while !Task.isCancelled, !placementConfirmed, Self.now() < deadline {
            try? await Task.sleep(for: .milliseconds(200))
        }
        guard !Task.isCancelled else { return }
        step = .framing
    }
}
