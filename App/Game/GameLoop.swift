import AganhaAudio
import AganhaCore
import AganhaVision
import CoreMedia
import Foundation
import Observation
import os
import UIKit

/// Orquestra relógio, Director/Reducer (AganhaCore), áudio e Vision → Judge → UI.
/// Roda na main thread; o `GameReducer` serializa todas as decisões de regra.
@MainActor
@Observable
final class GameLoop {
    enum Stage { case idle, positioning, playing }
    /// Antes da partida: conhecer os rostos de perto, mudar o aparelho de lugar, enquadrar todos,
    /// ligar cada vaga a um jogador (ou perguntar o nome) e esperar o gesto de começar.
    enum PositioningStep { case meeting, placing, framing, identifying, naming, ready }

    static let recentNamesKey = "recentNames"

    static let continueDelay = 5.0
    /// Espera depois do fim da janela para as últimas amostras da câmera (latência do Vision) chegarem.
    static let processingDelay = 0.12
    static let handsUpHold = 0.8

    var settings = GameSettings()
    private(set) var stage: Stage = .idle
    private(set) var state = GameState()
    private(set) var analysis: FrameAnalysis?
    private(set) var report = PositioningReport.empty
    var guidance: Guidance?
    private(set) var cameraError: String?
    private(set) var countdownText: String?
    private(set) var shownCommand: Command?
    private(set) var resultInfo: ResultInfo?
    var step: PositioningStep = .framing
    var names: [ChildSlot: String] = [:]
    var namingSlot: ChildSlot?
    var heardText = ""
    var isListening = false
    var namingNotice: String?
    /// Jogadores já apresentados nesta sessão e a vaga de cada um na tela.
    var met: [MetPlayer] = []
    var slotPlayers: [ChildSlot: UUID] = [:]
    var meetingPrompt = ""
    var faceProgress = 0.0
    var faceHint: String?
    var recognitionDebug: String?
    /// Quem acabou de ser reconhecido (tem uns segundos para dizer "não sou eu").
    var recognizedCandidate: MetPlayer?
    var awaitingName = false
    var consentRequest = false
    var typingRequest: TypingRequest?
    var recentNames = UserDefaults.standard.stringArray(forKey: GameLoop.recentNamesKey) ?? []

    let camera = CameraSession()
    let pipeline = PosePipeline()
    let profileStore = ProfileStore()
    let audio = AudioPlayer()
    let listener = NameListener()
    private var replay = ReplayBuffer()
    let logger = Logger(subsystem: "br.com.agacha.app", category: "gameloop")

    private var cameraRunning = false
    var gameTask: Task<Void, Never>?
    private var closeTask: Task<Void, Never>?
    private var resultTask: Task<Void, Never>?
    var promptTask: Task<Void, Never>?
    var namingTask: Task<Void, Never>?
    var meetingTask: Task<Void, Never>?
    var listenTask: Task<String, Error>?
    var readySince: Double?
    var consentContinuation: CheckedContinuation<Bool, Never>?
    var typingContinuation: CheckedContinuation<String?, Never>?
    var faceBuffer: [(time: Double, scan: FaceScan)] = []
    var slotSignatures: [ChildSlot: [AppearanceSignature]] = [:]
    var finishMeetingRequested = false
    var rejectRequested = false
    var placementConfirmed = false
    var quickName: String?

    var candidate: Guidance?
    var candidateSince = 0.0
    var spoken: Guidance?
    var lastSpokenAt = 0.0
    var handsUpSince: Double?

    nonisolated static func now() -> Double {
        CMClockGetTime(CMClockGetHostTimeClock()).seconds
    }

    // MARK: - Ciclo de vida

    /// Abre a tela Posicionar. `keepSlots` mantém as vagas e calibrações (jogar de novo).
    func startPositioning(keepSlots: Bool = false) {
        cancelGame()
        send(.quit)
        stage = .positioning
        report = .empty
        let meet = settings.askNames && !keepSlots
        step = meet ? .meeting : .framing
        if !keepSlots {
            names = [:]
            slotPlayers = [:]
        }
        met = []
        meetingPrompt = ""
        faceHint = nil
        faceProgress = 0
        recognitionDebug = nil
        pipeline.mode = .pose
        pipeline.computeAppearance = false
        namingSlot = nil
        namingNotice = nil
        readySince = nil
        guidance = nil
        candidate = nil
        spoken = nil
        handsUpSince = nil
        if !keepSlots { pipeline.requestReset() }
        replay.clear()
        UIApplication.shared.isIdleTimerDisabled = true
        Task {
            await startCamera()
            if meet, stage == .positioning { beginMeeting() }
        }
    }

    /// Sai para o menu: para tudo e desliga a câmera.
    func leave() {
        cancelGame()
        send(.quit)
        stage = .idle
        pipeline.mode = .pose
        pipeline.computeAppearance = false
        stopCamera()
        UIApplication.shared.isIdleTimerDisabled = false
    }

    /// `anyway`: começa com todas as pessoas vistas, mesmo sem o enquadramento completo.
    func startGame(anyway: Bool = false) {
        guard stage == .positioning else { return }
        let slots = anyway ? report.people.map(\.slot) : report.readySlots
        guard slots.count >= 2 else { return }
        promptTask?.cancel()
        namingTask?.cancel()
        meetingTask?.cancel()
        pipeline.computeAppearance = false
        audio.stop()
        // Durante o posicionamento as pessoas se mexem; a referência de "em pé" é refeita agora, com todos parados.
        pipeline.requestRecalibration()
        stage = .playing
        let config = GameConfig(slots: slots, difficulty: settings.difficulty, tolerance: settings.tolerance,
                                commandSet: settings.commandSet, seed: UInt64.random(in: 1...UInt64.max))
        send(.start(config))
    }

    func continueNow() {
        guard resultInfo?.isManual == true else { return }
        resultTask?.cancel()
        send(.next)
    }

    /// "Foi injusto!": repete a rodada sem eliminar ninguém.
    func unfair() {
        guard resultInfo?.isManual == true else { return }
        resultTask?.cancel()
        resultInfo = nil
        countdownText = String(localized: "Vamos repetir!")
        resultTask = Task {
            await audio.play("flow_repetir_rodada", fallbackText: "Tudo bem, vamos repetir essa!")
            guard !Task.isCancelled else { return }
            countdownText = nil
            send(.unfair)
        }
    }

    // MARK: - Câmera

    private func startCamera() async {
        guard !cameraRunning else { return }
        let pipeline = pipeline
        let loop = self
        camera.onFrame = { buffer, timestamp in
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

    private func stopCamera() {
        camera.stop()
        cameraRunning = false
    }

    private func ingest(_ analysis: FrameAnalysis) {
        self.analysis = analysis
        switch stage {
        case .idle:
            break
        case .positioning:
            if step == .meeting {
                observeFace(analysis)
                return
            }
            report = PositioningCheck.evaluate(analysis)
            if step == .framing {
                updateGuidance(report)
                advanceWhenReady(report, at: analysis.timestamp)
            }
            if step == .identifying { collectAppearance(analysis) }
            checkRaisedArms(report, at: analysis.timestamp)
        case .playing:
            replay.append(analysis)
            guard case .window = state.phase else { return }
            let samples = analysis.people.compactMap { person -> PostureSample? in
                guard let slot = person.slot else { return nil }
                return PostureSample(childSlot: slot, posture: person.reading.posture, timestamp: analysis.timestamp,
                                     crouchIndex: person.reading.crouchIndex)
            }
            send(.postureSamples(samples))
        }
    }

    // MARK: - Partida

    private func send(_ action: GameAction) {
        switch action {
        case .next, .unfair, .quit:
            resultInfo = nil
        default:
            break
        }
        for effect in GameReducer.reduce(&state, action) { handle(effect) }
    }

    private func handle(_ effect: GameEffect) {
        switch effect {
        case .startCountdown: runCountdown()
        case let .playCommand(command): playCommand(command)
        case let .scheduleWindowClose(time): scheduleClose(at: time)
        case let .showResult(result): showResult(result)
        case let .finished(result): celebrate(result)
        }
    }

    private func runCountdown() {
        let steps: [(clip: String, text: String, label: String)] = [
            ("flow_vamos_brincar", "Vamos brincar de Agacha!", String(localized: "Vamos brincar!")),
            ("flow_todos_em_pe", "Todo mundo em pé, de frente para mim!", String(localized: "Todos em pé!")),
            ("flow_preparados", "Preparados?", String(localized: "Preparados?")),
            ("flow_count_3", "Três!", "3"),
            ("flow_count_2", "Dois!", "2"),
            ("flow_count_1", "Um!", "1"),
            ("flow_count_go", "Já!", String(localized: "JÁ!"))
        ]
        gameTask = Task {
            for step in steps {
                countdownText = step.label
                await audio.play(step.clip, fallbackText: step.text)
                guard !Task.isCancelled else { return }
                if step.clip.hasPrefix("flow_count_") { try? await Task.sleep(for: .milliseconds(250)) }
                if step.clip == "flow_todos_em_pe" { await waitForCalibration() }
                guard !Task.isCancelled else { return }
            }
            countdownText = nil
            send(.countdownFinished)
        }
    }

    /// Espera todos os jogadores terminarem de calibrar "em pé" (ou desiste depois de alguns segundos).
    private func waitForCalibration(timeout: Double = 4) async {
        let slots = state.config?.slots ?? []
        let deadline = Self.now() + timeout
        countdownText = String(localized: "Fiquem parados!")
        while Self.now() < deadline, !Task.isCancelled {
            let ready = slots.allSatisfy { slot in
                analysis?.people.first { $0.slot == slot }?.reading.isCalibrated == true
            }
            if ready { return }
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    private func playCommand(_ command: Command) {
        let set = state.config?.commandSet ?? settings.commandSet
        gameTask = Task {
            await audio.play("cmd_\(set.audioID(for: command.word))", fallbackText: set.text(for: command.word)) {
                self.shownCommand = command
                self.send(.commandAudioStarted(at: Self.now()))
            }
        }
    }

    private func scheduleClose(at time: Double) {
        closeTask?.cancel()
        closeTask = Task {
            let wait = time + Self.processingDelay - Self.now()
            if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
            guard !Task.isCancelled else { return }
            send(.windowClosed)
        }
    }

    private func showResult(_ result: RoundResult) {
        shownCommand = nil
        let hasDrama = !result.eliminated.isEmpty || result.isTie
        let delay = hasDrama ? Self.continueDelay : Double(result.command.gapMs) / 1000
        if hasDrama {
            let replays = Dictionary(uniqueKeysWithValues: result.eliminated.map { ($0, replay.snapshots(for: $0, count: 3)) })
            resultInfo = ResultInfo(result: result, replays: replays, continueAt: Self.now() + delay, duration: delay,
                                    isManual: result.finished == nil || !result.eliminated.isEmpty)
        }
        let deadline = Self.now() + delay
        resultTask = Task {
            await playFeedback(for: result)
            let remaining = deadline - Self.now()
            if remaining > 0 { try? await Task.sleep(for: .seconds(remaining)) }
            guard !Task.isCancelled else { return }
            send(.next)
        }
    }

    private func cancelGame() {
        gameTask?.cancel()
        closeTask?.cancel()
        resultTask?.cancel()
        promptTask?.cancel()
        namingTask?.cancel()
        meetingTask?.cancel()
        listenTask?.cancel()
        answerConsent(false)
        resolveTyping(nil)
        audio.stop()
        awaitingName = false
        recognizedCandidate = nil
        shownCommand = nil
        countdownText = nil
        resultInfo = nil
    }
}
