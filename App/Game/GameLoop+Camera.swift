import AganhaCore
import AganhaVision
import Foundation

/// Câmera e análise dos quadros (posições, posturas e amostras para o julgamento).
extension GameLoop {
    // MARK: - Câmera

    func startCamera() async {
        guard !cameraRunning, !cameraStarting else { return }
        cameraStarting = true
        defer { cameraStarting = false }
        let pipeline = pipeline
        let recorder = recorder
        let streamer = tv.cameraStreamer
        let loop = self
        camera.onFrame = { buffer, timestamp in
            recorder.append(buffer, at: timestamp)
            streamer.offer(buffer, at: timestamp)
            let analysis = pipeline.process(pixelBuffer: buffer, timestamp: timestamp)
            Task { @MainActor in loop.ingest(analysis) }
        }
        _ = camera.setCenterStage(enabled: false)
        do {
            _ = try await camera.start()
            camera.updateRotationCoordinator()
            cameraRunning = true
            cameraError = nil
        } catch CameraError.denied {
            cameraError = String(localized: "Permita o acesso à câmera em Ajustes para jogar.")
        } catch {
            cameraError = String(localized: "Não foi possível iniciar a câmera.")
            logger.error("Câmera falhou: \(error.localizedDescription, privacy: .public)")
        }
    }

    func stopCamera() {
        camera.stop()
        cameraRunning = false
    }

    func ingest(_ analysis: FrameAnalysis) {
        self.analysis = analysis
        tv.cameraStreamer.setEnabled(tv.cameraOn && stage == .positioning)
        publishTVPose(analysis)
        switch stage {
        case .idle:
            break
        case .positioning:
            report = PositioningCheck.evaluate(analysis, minPlayers: settings.solo ? 1 : 2)
            if step == .framing {
                updateGuidance(report)
                advanceToNames(report, at: analysis.timestamp)
            }
            checkRaisedArms(report, at: analysis.timestamp)
        case .playing:
            replay.append(analysis)
            if case .gameOver = state.phase, gameOverControlsActive { checkPlayAgainGesture(analysis) }
            guard case .window = state.phase else { return }
            let samples = analysis.people.compactMap { person -> PostureSample? in
                guard let slot = person.slot else { return nil }
                return PostureSample(childSlot: slot, posture: person.reading.posture, timestamp: analysis.timestamp,
                                     crouchIndex: person.reading.crouchIndex)
            }
            send(.postureSamples(samples))
        }
    }

    // MARK: - Posicionar

    private func checkRaisedArms(_ report: PositioningReport, at time: Double) {
        let canStart = step == .ready || (!settings.askNames && step == .framing)
        guard canStart, report.allReady, report.anyRaisingBothArms else {
            handsUpSince = nil
            return
        }
        let since = handsUpSince ?? time
        handsUpSince = since
        if time - since >= Self.handsUpHold { startGame() }
    }

    private func guidance(for report: PositioningReport) -> Guidance {
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
    private func updateGuidance(_ report: PositioningReport) {
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
