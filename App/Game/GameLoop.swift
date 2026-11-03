import AganhaAudio
import AganhaCore
import AganhaTV
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
// swiftlint:disable:next type_body_length
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

    var settings = GameSettings.load() {
        didSet { settings.save() }
    }
    private(set) var stage: Stage = .idle
    private(set) var state = GameState()
    var analysis: FrameAnalysis?
    var report = PositioningReport.empty
    var guidance: Guidance?
    var cameraError: String?
    var countdownText: String?
    var shownCommand: Command?
    private(set) var resultInfo: ResultInfo?
    /// Vídeo temporário da última rodada com erro (apagado ao seguir em frente).
    var replayAsset: AVAsset?
    /// O vídeo do replay ainda está sendo preparado.
    var replayPending = false
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
    @ObservationIgnored let shots = ShotCapturer()
    /// Fotos reais ("shots") dos melhores momentos desta partida, na memória até a partida acabar.
    var shotCandidates: [Data] = []
    /// O momento da última partida, já salvo no aparelho (para compartilhar com as fotos).
    var lastSavedMoment: Moment?
    /// Clipe (MP4) dos últimos segundos da partida, guardado junto com o momento; pronto depois de `momentClipTask`.
    var momentClipURL: URL?
    var momentClipTask: Task<Void, Never>?
    /// Movimentos dos jogadores durante a partida (só números), para montar o vídeo de avatares no fim.
    @ObservationIgnored var poseTimeline = PoseTimeline()
    /// Momentos cujo vídeo de avatares ainda está sendo gerado.
    var videoJobs: Set<UUID> = []
    let tv = TVBridge()
    var lastTVPublish = 0.0
    var lastTVPose = 0.0
    /// Resultado do último treino solo.
    var soloScore = 0
    var soloBest = 0
    var soloIsRecord = false
    var lastTVState: TVState?
    var tvUpdatePending = false
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
    var resultTask: Task<Void, Never>?
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
        let candidates = anyway ? report.people.map(\.slot) : report.readySlots
        // No treino solo joga só uma pessoa (a mais à esquerda); as outras no quadro são ignoradas.
        let slots = settings.solo ? Array(candidates.prefix(1)) : candidates
        guard slots.count >= (settings.solo ? 1 : 2) else { return }
        promptTask?.cancel()
        namingTask?.cancel()
        audio.stop()
        // Durante o posicionamento as pessoas se mexem; a referência de "em pé" é refeita agora, com todos parados.
        pipeline.requestRecalibration()
        stage = .playing
        let config = GameConfig(slots: slots, difficulty: settings.difficulty, tolerance: settings.tolerance,
                                commandSet: settings.commandSet, seed: UInt64.random(in: 1...UInt64.max),
                                maxErrors: settings.maxErrors, displayDelay: settings.tvDelay, solo: settings.solo,
                                mode: settings.mode, scoreRounds: settings.scoreRounds, doubles: settings.doubles)
        // A câmera é gravada em pedaços curtos que se renovam: serve ao replay do erro (eliminação) e ao clipe do último movimento.
        if (settings.recordReplay && settings.mode == .elimination) || settings.saveMoments { recorder.start() }
        momentClipTask?.cancel()
        momentClipTask = nil
        momentClipURL = nil
        shotCandidates = []
        lastSavedMoment = nil
        poseTimeline.clear()
        shots.setArmed(settings.saveMoments)
        send(.start(config))
    }

    func continueNow() {
        guard resultInfo?.isManual == true else { return }
        resultTask?.cancel()
        resultInfo = nil
        releaseReplay()
        let needsCountdown = needsRestartCountdown
        resultTask = Task {
            if needsCountdown { await playRestartCountdown() }
            guard !Task.isCancelled else { return }
            send(.next)
        }
    }

    /// Depois de uma rodada com erro (e a partida seguindo), os jogadores precisam de "3, 2, 1" para voltar ao lugar.
    private var needsRestartCountdown: Bool {
        guard case let .result(result) = state.phase else { return false }
        return result.finished == nil && (!result.wrong.isEmpty || result.isTie)
    }

    /// "Foi injusto!": repete a rodada sem eliminar ninguém.
    func unfair() {
        guard resultInfo?.isManual == true else { return }
        resultTask?.cancel()
        resultInfo = nil
        countdownText = String(localized: "Vamos repetir!")
        resultTask = Task {
            releaseReplay()
            await audio.play("flow_repetir_rodada", fallbackText: "Tudo bem, vamos repetir essa!")
            guard !Task.isCancelled else { return }
            await playRestartCountdown()
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
            if !settings.saveMoments { recorder.stop() }
            if state.config?.mode == .score { recordSoloCoins() } else { recordSoloScore() }
            saveMoment(result)
            celebrate(result)
        }
    }

    private func runCountdown() {
        let intro = [
            CountdownStep(clip: "flow_vamos_brincar", text: "Vamos brincar de Agacha!", label: String(localized: "Vamos brincar!")),
            CountdownStep(clip: "flow_todos_em_pe", text: "Todo mundo em pé, de frente para mim!", label: String(localized: "Todos em pé!"))
        ]
        gameTask = Task {
            await playCountdown(intro + Self.readySteps, pauseAfter: ("flow_todos_em_pe", { await self.waitForCalibration() }))
            guard !Task.isCancelled else { return }
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
            if let cue = command.cue { await announce(cue) }
            guard !Task.isCancelled else { return }
            await audio.play("cmd_\(set.audioID(for: command.word))", fallbackText: set.text(for: command.word)) {
                self.shownCommand = command
                self.send(.commandAudioStarted(at: Self.now()))
            }
            // Comando duplo: a segunda palavra vem logo em seguida, sem a pausa de uma rodada normal.
            guard let follow = command.followUp, let second = command.secondStep, !Task.isCancelled else { return }
            if follow.gapMs > 0 { try? await Task.sleep(for: .milliseconds(follow.gapMs)) }
            guard !Task.isCancelled else { return }
            await audio.play("cmd_\(set.audioID(for: follow.word))", fallbackText: set.text(for: follow.word)) {
                self.shownCommand = second
                self.send(.followUpAudioStarted(at: Self.now()))
            }
        }
    }

    /// "Mais rápido!" / "Agora vai ficar difícil!" antes do comando, como o adulto que vai apertando o ritmo.
    private func announce(_ cue: Cue) async {
        let (clip, text) = cue == .faster ? ("flow_mais_rapido", "Mais rápido!") : ("flow_ficou_dificil", "Agora vai ficar difícil!")
        countdownText = text
        await audio.play(clip, fallbackText: text)
        countdownText = nil
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
        captureHighlight(result)
        if result.finished != nil { captureLastMovementClip() }
        if state.config?.mode == .score {
            showScoreResult(result)
            return
        }
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
            replayPending = true
            replayTask = Task {
                let asset = await recorder.capture(seconds: 4)
                guard !Task.isCancelled else { return }
                replayAsset = asset
                replayPending = false
                // Na TV só com o vídeo ligado (que exige o código na URL): ela baixa os quadros do mesmo replay do iPad.
                if tv.isOn, tv.cameraOn, let asset {
                    let frames = await recorder.exportFrames(ReplayAsset(asset))
                    if !Task.isCancelled { tv.setReplay(frames) }
                }
            }
        }
        let deadline = Self.now() + delay
        let needsCountdown = hasDrama && result.finished == nil
        resultTask = Task {
            await playFeedback(for: result)
            let remaining = deadline - Self.now()
            if remaining > 0 { try? await Task.sleep(for: .seconds(remaining)) }
            guard !Task.isCancelled else { return }
            if needsCountdown {
                resultInfo = nil
                releaseReplay()
                await playRestartCountdown()
                guard !Task.isCancelled else { return }
            }
            send(.next)
        }
    }

    /// Fim do replay: descarta o vídeo temporário e volta a gravar.
    private func releaseReplay() {
        replayTask?.cancel()
        replayAsset = nil
        replayPending = false
        tv.setReplay([])
        recorder.resume()
    }

    private func cancelGame() {
        gameTask?.cancel()
        gameOverTask?.cancel()
        gameOverControlsActive = false
        replayTask?.cancel()
        replayAsset = nil
        recorder.stop()
        momentClipTask?.cancel()
        momentClipTask = nil
        shots.setArmed(false)
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
