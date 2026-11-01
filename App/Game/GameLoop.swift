import AganhaAudio
import AganhaCore
import AganhaVision
import CoreMedia
import Observation
import os
import UIKit

struct GameSettings: Equatable {
    var difficulty: Difficulty = .sapeca
    var tolerance: Tolerance = .normal
    var commandSet: CommandSet = .classic
}

/// Orientação falada e escrita na tela Posicionar.
struct Guidance: Equatable {
    let clip: String
    let text: String
    let slot: ChildSlot?
}

/// O que a tela "Alguém errou" mostra depois de uma rodada.
struct ResultInfo: Equatable {
    let result: RoundResult
    /// Até 3 quadros de esqueleto por criança eliminada.
    let replays: [ChildSlot: [Skeleton]]
    let continueAt: Double
    let duration: Double
    /// Mostra os botões "Foi injusto!" e "Continuar".
    let isManual: Bool
}

/// Orquestra relógio, Director/Reducer (AganhaCore), áudio e Vision → Judge → UI.
/// Roda na main thread; o `GameReducer` serializa todas as decisões de regra.
@MainActor
@Observable
final class GameLoop {
    enum Stage { case idle, positioning, playing }

    static let continueDelay = 5.0
    /// Espera depois do fim da janela para as últimas amostras da câmera (latência do Vision) chegarem.
    static let processingDelay = 0.12
    static let handsUpHold = 0.8

    var settings = GameSettings()
    private(set) var stage: Stage = .idle
    private(set) var state = GameState()
    private(set) var analysis: FrameAnalysis?
    private(set) var report = PositioningReport.empty
    private(set) var guidance: Guidance?
    private(set) var cameraError: String?
    private(set) var countdownText: String?
    private(set) var shownCommand: Command?
    private(set) var resultInfo: ResultInfo?

    let camera = CameraSession()
    private let pipeline = PosePipeline()
    private let audio = AudioPlayer()
    private var replay = ReplayBuffer()
    private let logger = Logger(subsystem: "br.com.agacha.app", category: "gameloop")

    private var cameraRunning = false
    private var gameTask: Task<Void, Never>?
    private var closeTask: Task<Void, Never>?
    private var resultTask: Task<Void, Never>?
    private var promptTask: Task<Void, Never>?

    private var candidate: Guidance?
    private var candidateSince = 0.0
    private var spoken: Guidance?
    private var lastSpokenAt = 0.0
    private var handsUpSince: Double?

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
        audio.stop()
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
            report = PositioningCheck.evaluate(analysis)
            updateGuidance(report)
            checkRaisedArms(report, at: analysis.timestamp)
        case .playing:
            replay.append(analysis)
            guard case .window = state.phase else { return }
            let samples = analysis.people.compactMap { person -> PostureSample? in
                guard let slot = person.slot else { return nil }
                return PostureSample(childSlot: slot, posture: person.reading.posture, timestamp: analysis.timestamp)
            }
            send(.postureSamples(samples))
        }
    }

    // MARK: - Posicionar

    private func checkRaisedArms(_ report: PositioningReport, at time: Double) {
        guard report.allReady, report.anyRaisingBothArms else {
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
            if next.clip == "setup_comecar_bracos" {
                await audio.play("setup_pronto", fallbackText: "Pronto! Já vi todo mundo!")
            }
            guard !Task.isCancelled else { return }
            await audio.play(next.clip, fallbackText: next.text)
            lastSpokenAt = Self.now()
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
            }
            countdownText = nil
            send(.countdownFinished)
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

    private func playFeedback(for result: RoundResult) async {
        if result.isTie {
            await audio.play("fb_empate", fallbackText: "Todos erraram juntos!")
            return
        }
        for slot in result.eliminated {
            let name = SlotColors.name(slot)
            await audio.play("cor_\(name)_errou", fallbackText: "\(SlotColors.displayName(slot)) errou!")
            if Task.isCancelled { return }
        }
        if result.finished == nil, !result.eliminated.isEmpty, result.survivors.count == 2 {
            await audio.play("fb_restam_dois", fallbackText: "Só restam dois! É a final!")
        }
    }

    private func celebrate(_ result: GameResult) {
        gameTask = Task {
            if let winner = result.winners.first, !result.isTie {
                await audio.play("cor_\(SlotColors.name(winner))_venceu",
                                 fallbackText: "\(SlotColors.displayName(winner)) venceu! Parabéns!")
                guard !Task.isCancelled else { return }
                await audio.play("fb_campeao", fallbackText: "Temos um campeão! Parabéns!")
            } else {
                await audio.play("fb_fim_de_jogo", fallbackText: "Fim de jogo!")
            }
        }
    }

    private func cancelGame() {
        gameTask?.cancel()
        closeTask?.cancel()
        resultTask?.cancel()
        promptTask?.cancel()
        audio.stop()
        shownCommand = nil
        countdownText = nil
        resultInfo = nil
    }
}
