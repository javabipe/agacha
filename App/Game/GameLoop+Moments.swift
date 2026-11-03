import AganhaCore
import SwiftUI
import UIKit

/// Momentos: durante a partida guarda fotos reais ("shots") dos melhores instantes; no fim salva tudo no aparelho
/// (pôster de avatares + fotos) para a tela Momentos. Só se a opção estiver ligada nos Ajustes.
extension GameLoop {
    static let maxShotsPerGame = 3

    /// Foto de um instante marcante da rodada: um acerto PERFEITO (pontuação) ou um erro (eliminação).
    func captureHighlight(_ result: RoundResult) {
        guard settings.saveMoments, shotCandidates.count < Self.maxShotsPerGame else { return }
        let scoring = state.config?.mode == .score
        let notable = scoring ? result.scores.values.contains { $0.tier == .perfect } : !result.wrong.isEmpty
        guard notable, let shot = shots.snapshot() else { return }
        shotCandidates.append(shot)
    }

    /// Resultado da partida como um momento (os mesmos dados do placar).
    func makeMoment(_ result: GameResult) -> Moment {
        let config = state.config
        let scoring = config?.mode == .score
        let players = result.ranking.compactMap { slot -> Moment.Player? in
            guard let player = state.players[slot] else { return nil }
            let wins = result.winners.contains(slot) && (scoring ? player.coins > 0 : true)
            return Moment.Player(name: name(for: slot), colorHex: SlotColors.hex(slot),
                                 coins: scoring ? player.coins : player.correct, isWinner: wins)
        }
        let fastest = state.players.values.compactMap(\.bestReactionMs).min()
        return Moment(title: config?.solo == true ? String(localized: "Treino solo") : String(localized: "Partida de hoje"),
                      place: String(localized: "Em casa"), ago: String(localized: "agora"),
                      durationSeconds: max(10, state.history.count * 3), views: 0, likes: 0, mode: config?.mode ?? .score,
                      rounds: state.history.count, fastestMs: fastest, players: players)
    }

    /// No fim da partida: foto final + fotos dos destaques + pôster de avatares, salvos só no aparelho.
    func saveMoment(_ result: GameResult) {
        guard settings.saveMoments else { return }
        var collected = shotCandidates
        if let final = shots.snapshot() { collected.insert(final, at: 0) }
        let photos = collected
        shotCandidates = []
        shots.setArmed(false)
        let moment = makeMoment(result)
        let poster = Self.renderPoster(moment)
        Task {
            let saved = await Task.detached { MomentStore.shared.save(moment, poster: poster, shots: photos) }.value
            lastSavedMoment = saved
        }
    }

    /// Pôster vertical (imagem) com os avatares dançando e chorando e o placar.
    @MainActor static func renderPoster(_ moment: Moment) -> Data? {
        let view = MomentPreview(moment: moment, frozenAt: 0.25).frame(width: 360, height: 640)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        return renderer.uiImage?.pngData()
    }
}
