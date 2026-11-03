import AganhaCore
import AganhaTV
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
    func trackTV() {
        guard tv.isOn else { return }
        let state = withObservationTracking {
            tvState()
        } onChange: { [weak self] in
            Task { @MainActor in self?.trackTV() }
        }
        tv.publish(state)
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
            if case let .gameOver(result) = state.phase {
                let winners = result.winners.map { name(for: $0) }
                let message = result.isTie ? "Empate!" : "\(winners.first ?? "") venceu!"
                return TVState(screen: "gameover", message: message, players: players)
            }
            if let info = resultInfo {
                let who = Self.joined(info.result.wrong.map { name(for: $0) })
                return TVState(screen: "result", message: info.result.isTie ? "Todos erraram juntos!" : "\(who) errou!", players: players)
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
}
