import AganhaAudio
import AganhaCore
import AganhaVision
import AVFoundation
import CoreMedia
import Observation
import os
import UIKit

/// Orquestra relógio, Director/Reducer (AganhaCore), áudio e Vision → Judge → UI.
/// Roda na main thread; o `GameReducer` serializa todas as decisões de regra.
@MainActor
@Observable
final class GameLoop {
    enum Stage { case idle, positioning, playing }
    /// Posicionar tem três momentos: enquadrar todos, perguntar os nomes e esperar o gesto de começar.
    enum PositioningStep { case framing, naming, typing, ready }

    static let recentNamesKey = "recentNames"

    static let continueDelay = 5.0
    /// Com o vídeo do replay, mais tempo para assistir antes de seguir sozinho.
    static let continueDelayWithVideo = 10.0
    /// Espera depois do fim da janela para as últimas amostras da câmera (latência do Vision) chegarem.
    static let processingDelay = 0.12
    static let handsUpHold = 0.8

    var settings = GameSettings()
    private(set) var stage: Stage = .idle
    private(set) var state = GameState()
    var analysis: FrameAnalysis?
    var report = PositioningReport.empty
    var guidance: Guidance?
    var cameraError: String?
    private(set) var countdownText: String?
    private(set) var shownCommand: Command?
    private(set) var resultInfo: ResultInfo?
    /// Vídeo temporário da última rodada com erro (apagado ao seguir em frente).
    var replayAsset: AVAsset?
    /// Fim de partida: pediram para voltar ao menu (por voz).
    var wantsMenu = false
    var step: PositioningStep = .framing
    var names: [ChildSlot: String] = [:]
    var namingSlot: ChildSlot?
    var heardText = ""
    var isListening = false
    var namingNotice: String?
    /// Quem está sendo digitado agora (quando a voz não está disponível) e quem ainda falta.
    var typingSlot: ChildSlot?
    var typingQueue: [ChildSlot] = []
    var recentNames = UserDefaults.standard.stringArray(forKey: GameLoop.recentNamesKey) ?? []

    let camera = CameraSession()
    let pipeline = PosePipeline()
    let recorder = ClipRecorder()
    let audio = AudioPlayer()
    let listener = NameListener()
    var replay = ReplayBuffer()
    let logger = Logger(subsystem: "br.com.agacha.app", category: "gameloop")

    var cameraRunning = false
    var cameraStarting = false
    var gameTask: Task<Void, Never>?
    var gameOverTask: Task<Void, Never>?
    /// Só depois da comemoração o fim de partida aceita o gesto/voz de "de novo".
    var gameOverControlsActive = false
    var playAgainSince: Double?
    var replayTask: Task<Void, Never>?
    private var closeTask: Task<Void, Never>?
    private var resultTask: Task<Void, Never>?
    var promptTask: Task<Void, Never>?
    var namingTask: Task<Void, Never>?
    var readySince: Double?

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
        step = .framing
        if !keepSlots { names = [:] }
        namingSlot = nil
        typingSlot = nil
        typingQueue = []
        namingNotice = nil
        readySince = nil
        guidance = nil
        candidate = nil
        spoken = nil
        handsUpSince = nil
        if !keepSlots { pipeline.requestReset() }
        replay.clear()
        UIApplication.shared.isIdleTimerDisabled = true
        Task { await startCamera() }
    }

    /// Sai para o menu: para tudo e desliga a câmera.
    func leave() {
        cancelGame()
        wantsMenu = false
        send(.quit)
        stage = .idle
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
        audio.stop()
        // Durante o posicionamento as pessoas se mexem; a referência de "em pé" é refeita agora, com todos parados.
        pipeline.requestRecalibration()
        stage = .playing
        let config = GameConfig(slots: slots, difficulty: settings.difficulty, tolerance: settings.tolerance,
                                commandSet: settings.commandSet, seed: UInt64.random(in: 1...UInt64.max),
                                maxErrors: settings.maxErrors)
        if settings.recordReplay { recorder.start() }
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

    // MARK: - Partida

    func send(_ action: GameAction) {
        switch action {
        case .next, .unfair, .quit:
            resultInfo = nil
            releaseReplay()
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
        case let .finished(result):
            recorder.stop()
            celebrate(result)
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
        let hasDrama = !result.wrong.isEmpty || result.isTie
        let withVideo = hasDrama && settings.recordReplay
        let delay = hasDrama ? (withVideo ? Self.continueDelayWithVideo : Self.continueDelay) : Double(result.command.gapMs) / 1000
        if hasDrama {
            let replays = Dictionary(uniqueKeysWithValues: result.wrong.map { ($0, replay.snapshots(for: $0, count: 3)) })
            resultInfo = ResultInfo(result: result, replays: replays, continueAt: Self.now() + delay, duration: delay,
                                    isManual: result.finished == nil || !result.eliminated.isEmpty)
        }
        if withVideo {
            replayTask = Task {
                let asset = await recorder.capture(seconds: 4)
                guard !Task.isCancelled else { return }
                replayAsset = asset
            }
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

    /// Fim do replay: descarta o vídeo temporário e volta a gravar.
    private func releaseReplay() {
        replayTask?.cancel()
        replayAsset = nil
        recorder.resume()
    }

    private func cancelGame() {
        gameTask?.cancel()
        gameOverTask?.cancel()
        gameOverControlsActive = false
        replayTask?.cancel()
        replayAsset = nil
        recorder.stop()
        closeTask?.cancel()
        resultTask?.cancel()
        promptTask?.cancel()
        namingTask?.cancel()
        audio.stop()
        shownCommand = nil
        countdownText = nil
        resultInfo = nil
    }
}
