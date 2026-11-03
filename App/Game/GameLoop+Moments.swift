import AganhaCore
import AganhaVision
import AVFoundation
import SwiftUI
import UIKit

/// Momentos: no fim da partida salva, só no aparelho, o pôster de avatares e o replay do erro (se houve)
/// (pôster de avatares + fotos) para a tela Momentos. Só se a opção estiver ligada nos Ajustes.
extension GameLoop {
    /// Guarda o replay do erro (os mesmos ~4 s mostrados na tela) como MP4, para compartilhar com o momento.
    func keepErrorClip(_ asset: AVAsset) async {
        let url = FileManager.default.temporaryDirectory.appending(path: "agacha-erro-\(UUID().uuidString).mp4")
        guard await recorder.exportMP4(ReplayAsset(asset), to: url) else { return }
        if let old = errorClipURL { try? FileManager.default.removeItem(at: old) }
        errorClipURL = url
    }

    /// Resultado da partida como um momento (os mesmos dados do placar).
    func makeMoment(_ result: GameResult) -> Moment {
        let config = state.config
        let scoring = config?.mode == .score
        let players = result.ranking.compactMap { slot -> Moment.Player? in
            guard let player = state.players[slot] else { return nil }
            let wins = result.winners.contains(slot) && (scoring ? player.coins > 0 : true)
            return Moment.Player(name: name(for: slot), colorHex: SlotColors.hex(slot),
                                 coins: scoring ? player.coins : player.correct, isWinner: wins, isGirl: look(for: slot) == .girl)
        }
        let fastest = state.players.values.compactMap(\.bestReactionMs).min()
        return Moment(title: config?.solo == true ? String(localized: "Treino solo") : String(localized: "Partida de hoje"),
                      place: String(localized: "Em casa"), ago: String(localized: "agora"),
                      durationSeconds: max(10, state.history.count * 3), views: 0, likes: 0, mode: config?.mode ?? .score,
                      rounds: state.history.count, fastestMs: fastest, players: players)
    }

    /// No fim da partida: pôster de avatares + (se houve erro com replay) o replay do erro e uma foto dele, salvos só no aparelho.
    func saveMoment(_ result: GameResult) {
        guard settings.saveMoments else { return }
        let moment = makeMoment(result)
        let poster = Self.renderPoster(moment)
        let job = makeVideoJob(result, moment: moment)
        let clip = errorClipURL
        errorClipURL = nil
        Task {
            var still: Data?
            if let clip { still = await VideoThumbnail.jpeg(for: clip, fraction: 0.5) }
            let photos = still.map { [$0] } ?? []
            let saved = await Task.detached { MomentStore.shared.save(moment, poster: poster, shots: photos, clip: clip) }.value
            lastSavedMoment = saved
            if saved != nil, let job { await generateVideo(job) }
        }
    }

    var isGameOverPhase: Bool {
        if case .gameOver = state.phase { return true }
        return false
    }

    /// O vídeo de avatares só é montado com o jogo parado no menu (câmera desligada), para nunca atrapalhar a câmera nem a TV.
    var isCameraBusy: Bool { stage != .idle }

    private func makeVideoJob(_ result: GameResult, moment: Moment) -> AvatarVideoJob? {
        let scoring = state.config?.mode == .score
        let players = result.ranking.compactMap { slot -> AvatarVideoPlayer? in
            guard let player = state.players[slot] else { return nil }
            let wins = result.winners.contains(slot) && (scoring ? player.coins > 0 : true)
            return AvatarVideoPlayer(slot: slot, name: name(for: slot), colorHex: SlotColors.hex(slot), isWinner: wins,
                                     isGirl: look(for: slot) == .girl)
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
        let done = await AvatarVideoExporter.export(job, to: temp, shouldPause: { [weak self] in self?.isCameraBusy ?? false })
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
