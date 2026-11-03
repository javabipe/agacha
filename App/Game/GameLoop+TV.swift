import AganhaCore
import AganhaTV
import AganhaVision
import Foundation
import Observation

/// O que a TV mostra: o mesmo estado do jogo, sem imagem de câmera.
extension GameLoop {
    func setTVEnabled(_ on: Bool) {
        Task {
            await tv.setEnabled(on)
            audio.remote = on ? tv.audioOutput : nil
            trackTV()
        }
    }

    /// Manda o estado à TV agora e de novo a cada mudança (a observação vale uma vez e é rearmada).
    /// Os bonecos da tela de posicionamento mudam a cada quadro, então vão no máximo 10 vezes por segundo.
    func trackTV() {
        guard tv.isOn else { return }
        let state = withObservationTracking {
            tvState()
        } onChange: { [weak self] in
            Task { @MainActor in self?.scheduleTVUpdate() }
        }
        guard state != lastTVState else { return }
        lastTVState = state
        lastTVPublish = Self.now()
        tv.publish(state)
    }

    private func scheduleTVUpdate() {
        guard !tvUpdatePending else { return }
        let minInterval = stage == .positioning ? 0.1 : 0
        let wait = minInterval - (Self.now() - lastTVPublish)
        guard wait > 0 else {
            trackTV()
            return
        }
        tvUpdatePending = true
        Task {
            try? await Task.sleep(for: .seconds(wait))
            tvUpdatePending = false
            trackTV()
        }
    }

    /// Posição dos jogadores para os avatares da TV (só juntas do corpo; nunca a imagem). Até ~30 vezes por segundo.
    func publishTVPose(_ analysis: FrameAnalysis) {
        guard tv.isOn, tv.connectedScreens > 0, stage != .idle, analysis.imageSize.height > 0 else { return }
        let now = Self.now()
        guard now - lastTVPose >= 0.03 else { return }   // ~1 por quadro da câmera (30/s)
        lastTVPose = now
        func rounded(_ value: Double) -> Double { (value * 1000).rounded() / 1000 }
        let keys: [JointName: String] = [
            .nose: "n", .leftEye: "ley", .rightEye: "rey", .leftEar: "lea", .rightEar: "rea",
            .leftShoulder: "ls", .rightShoulder: "rs", .leftElbow: "le", .rightElbow: "re",
            .leftWrist: "lw", .rightWrist: "rw", .leftHip: "lh", .rightHip: "rh",
            .leftKnee: "lk", .rightKnee: "rk", .leftAnkle: "la", .rightAnkle: "ra"
        ]
        let figures = analysis.people.compactMap { person -> TVState.Figure? in
            guard let slot = person.slot else { return nil }
            var joints: [String: [Double]] = [:]
            for (joint, key) in keys {
                if let value = person.skeleton.joints[joint], value.confidence > 0.2 { joints[key] = [rounded(value.x), rounded(value.y)] }
            }
            let ready = stage == .playing || (report.people.first { $0.slot == slot }?.isReady ?? false)
            return TVState.Figure(name: name(for: slot), color: SlotColors.hex(slot), ready: ready, joints: joints)
        }
        tv.publishPose(TVPose(aspect: analysis.imageSize.width / analysis.imageSize.height, figures: figures))
    }

    func tvState() -> TVState {
        var tvState = baseTVState()
        if stage == .playing, let config = state.config, config.mode == .score {
            let entries = config.slots.map { slot -> TVState.ScoreEntry in
                let player = state.players[slot]
                let score = lastScore(for: slot)
                return TVState.ScoreEntry(name: name(for: slot), color: SlotColors.hex(slot), tier: score?.tier.rawValue ?? "",
                                           ms: score?.reactionMs, gain: score?.coins ?? 0, total: player?.coins ?? 0,
                                           combo: player?.combo ?? 0, multiplier: score?.multiplier ?? 1,
                                           double: score?.isDouble ?? false)
            }
            tvState.score = TVState.Score(round: state.history.count, rounds: config.scoreRounds, entries: entries)
        }
        return tvState
    }

    private func baseTVState() -> TVState {
        let set = state.config?.commandSet ?? settings.commandSet
        switch stage {
        case .idle:
            return TVState(screen: "menu", banner: "Agacha!")
        case .positioning:
            let players = report.people.map { person in
                TVState.Player(name: name(for: person.slot), color: SlotColors.hex(person.slot), out: !person.isReady,
                               detail: person.isReady ? "✓" : "!")
            }
            let banner = bannerText.split(separator: "\n").first.map(String.init)
            return TVState(screen: "positioning", banner: banner, players: players)
        case .playing:
            let players = (state.config?.slots ?? []).map { slot in
                TVState.Player(name: name(for: slot), color: SlotColors.hex(slot),
                               out: state.players[slot]?.isEliminated ?? false, detail: statusDetail(for: slot))
            }
            if case .gameOver = state.phase, state.config?.solo == true {
                let summary = isScoreMode ? "Fim: \(soloScore) moedas!" : "Fim do treino: \(soloScore) acertos!"
                // Só um recorde faz o treino solo comemorar; senão a tela fica como está.
                let hero = soloIsRecord ? state.config?.slots.first.map { [name(for: $0)] } : nil
                return TVState(screen: "gameover", message: summary, players: players, winners: hero)
            }
            if case let .gameOver(result) = state.phase {
                let winners = result.winners.map { name(for: $0) }
                let message = result.isTie ? "Empate!" : "\(winners.first ?? "") venceu!"
                return TVState(screen: "gameover", message: message, players: players, winners: winners)
            }
            if let info = resultInfo {
                let who = Self.joined(info.result.wrong.map { name(for: $0) })
                return TVState(screen: "result", message: info.result.isTie ? "Todos erraram juntos!" : "\(who) errou!", players: players,
                               replay: tv.replay, note: measurementNote(info))
            }
            guard let command = shownCommand else {
                return TVState(screen: "play", banner: countdownText, players: players)
            }
            return TVState(screen: "play", word: set.text(for: command.word), background: set.colorHex(for: command.word),
                           gesture: command.gesture.rawValue, trick: command.isTrick, players: players)
        }
    }

    /// "Paulo, Arthur e Bia".
    static func joined(_ names: [String]) -> String {
        switch names.count {
        case 0: ""
        case 1: names[0]
        default: names.dropLast().joined(separator: ", ") + " e " + names[names.count - 1]
        }
    }

    /// "Paulo: mediu 0,36 · precisava ≤ 0,25" (o mesmo diagnóstico da tela do iPad).
    private func measurementNote(_ info: ResultInfo) -> String? {
        guard let slot = info.result.wrong.first, let index = info.result.details[slot]?.crouchIndex,
              let rules = state.config?.rules else { return nil }
        let word = info.result.failedWords[slot] ?? info.result.command.word
        let needed = word == .up ? "≤ \(rules.standMax)" : "≥ \(rules.crouchMin)"
        return "\(name(for: slot)): mediu \(index.formatted(.number.precision(.fractionLength(2)))) · precisava \(needed)"
    }
}
