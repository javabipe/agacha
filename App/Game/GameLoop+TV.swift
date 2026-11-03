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

    /// Posição dos jogadores para os avatares da TV (só juntas do corpo; nunca a imagem). No máximo ~10 vezes por segundo.
    func publishTVPose(_ analysis: FrameAnalysis) {
        guard tv.isOn, tv.connectedScreens > 0, stage != .idle, analysis.imageSize.height > 0 else { return }
        let now = Self.now()
        guard now - lastTVPose >= 0.1 else { return }
        lastTVPose = now
        func rounded(_ value: Double) -> Double { (value * 1000).rounded() / 1000 }
        let keys: [JointName: String] = [
            .nose: "n", .leftShoulder: "ls", .rightShoulder: "rs", .leftElbow: "le", .rightElbow: "re",
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
                return TVState(screen: "gameover", message: "Fim do treino: \(soloScore) acertos!", players: players)
            }
            if case let .gameOver(result) = state.phase {
                let winners = result.winners.map { name(for: $0) }
                let message = result.isTie ? "Empate!" : "\(winners.first ?? "") venceu!"
                return TVState(screen: "gameover", message: message, players: players)
            }
            if let info = resultInfo {
                let who = Self.joined(info.result.wrong.map { name(for: $0) })
                let command = info.result.command
                return TVState(screen: "result", word: set.text(for: command.word), background: set.colorHex(for: command.word),
                               gesture: command.gesture.rawValue, trick: command.isTrick,
                               message: info.result.isTie ? "Todos erraram juntos!" : "\(who) errou!", players: players,
                               replay: tv.hasReplay ? "/replay.mp4?v=\(tv.replayVersion)" : nil, note: measurementNote(info))
            }
            guard let command = shownCommand else {
                return TVState(screen: "play", banner: countdownText, players: players)
            }
            return TVState(screen: "play", word: set.text(for: command.word), background: set.colorHex(for: command.word),
                           gesture: command.gesture.rawValue, trick: command.isTrick, players: players, command: command.number)
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
        let needed = info.result.command.word == .up ? "≤ \(rules.standMax)" : "≥ \(rules.crouchMin)"
        return "\(name(for: slot)): mediu \(index.formatted(.number.precision(.fractionLength(2)))) · precisava \(needed)"
    }
}
