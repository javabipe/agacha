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
        let job = makeVideoJob(result, moment: moment)
        Task {
            let saved = await Task.detached { MomentStore.shared.save(moment, poster: poster, shots: photos) }.value
            lastSavedMoment = saved
            if saved != nil, let job { await generateVideo(job) }
        }
    }

    var isGameOverPhase: Bool {
        if case .gameOver = state.phase { return true }
        return false
    }

    /// Enquanto uma partida está rolando o vídeo espera (para não atrapalhar a câmera nem a TV).
    var isRoundActive: Bool { stage == .playing && !isGameOverPhase }

    private func makeVideoJob(_ result: GameResult, moment: Moment) -> AvatarVideoJob? {
        let scoring = state.config?.mode == .score
        let players = result.ranking.compactMap { slot -> AvatarVideoPlayer? in
            guard let player = state.players[slot] else { return nil }
            let wins = result.winners.contains(slot) && (scoring ? player.coins > 0 : true)
            return AvatarVideoPlayer(slot: slot, name: name(for: slot), colorHex: SlotColors.hex(slot), isWinner: wins)
        }
        guard poseTimeline.frames.count >= 12, !players.isEmpty,
              let framing = poseTimeline.framing(targetAspect: 9.0 / 16.0) else { return nil }
        return AvatarVideoJob(frames: poseTimeline.frames, aspect: poseTimeline.aspect, framing: framing, moment: moment, players: players)
    }

    /// Gera o vídeo de avatares do momento já salvo e o guarda junto dele.
    private func generateVideo(_ job: AvatarVideoJob) async {
        let id = job.moment.id
        videoJobs.insert(id)
        defer { videoJobs.remove(id) }
        let temp = FileManager.default.temporaryDirectory.appending(path: "avatares-\(id.uuidString).mp4")
        let done = await AvatarVideoExporter.export(job, to: temp, shouldPause: { [weak self] in self?.isRoundActive ?? false })
        guard done, let updated = MomentStore.shared.attachVideo(to: id, from: temp) else {
            try? FileManager.default.removeItem(at: temp)
            return
        }
        lastSavedMoment = updated
    }

    /// Pôster vertical (imagem) com os avatares dançando e chorando e o placar.
    @MainActor static func renderPoster(_ moment: Moment) -> Data? {
        let view = MomentPreview(moment: moment, frozenAt: 0.25).frame(width: 360, height: 640)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        return renderer.uiImage?.pngData()
    }
}
