import AganhaCore
import AganhaVision
import AVFoundation
import SwiftUI
import UIKit

/// Quem aparece no vídeo de avatares.
struct AvatarVideoPlayer: Sendable {
    let slot: ChildSlot
    let name: String
    let colorHex: String
    let isWinner: Bool
}

/// Tudo que o vídeo de avatares precisa (só números e textos; nenhuma imagem da câmera).
struct AvatarVideoJob: Sendable {
    let frames: [PoseFrame]
    let aspect: Double
    let framing: PoseFraming
    let moment: Moment
    let players: [AvatarVideoPlayer]
}

/// Monta o vídeo vertical (9:16) só com avatares: a partida inteira (até 60 s) com os movimentos reais de cada jogador e,
/// no fim, 3 s de dancinha de quem ganhou e choro de quem perdeu, sobre o placar. Sem nenhum rosto de verdade.
@MainActor
enum AvatarVideoExporter {
    /// Pixels do vídeo; o desenho é feito em 360×640 pontos (como o pôster) e ampliado 1,5×.
    static let size = CGSize(width: 540, height: 960)
    static let layoutSize = CGSize(width: 360, height: 640)
    static let framesPerSecond = 12
    static let finalSeconds = 3.0

    /// Escreve o MP4 em `url`. `shouldPause` deixa o trabalho esperar enquanto a partida seguinte está rodando.
    static func export(_ job: AvatarVideoJob, to url: URL, shouldPause: @MainActor () -> Bool = { false }) async -> Bool {
        guard let first = job.frames.first, let last = job.frames.last else { return false }
        try? FileManager.default.removeItem(at: url)
        guard let writer = try? AVAssetWriter(outputURL: url, fileType: .mp4) else { return false }
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: Int(size.width), AVVideoHeightKey: Int(size.height),
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 1_500_000]
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(size.width), kCVPixelBufferHeightKey as String: Int(size.height)
        ])
        guard writer.canAdd(input) else { return false }
        writer.add(input)
        guard writer.startWriting() else { return false }
        writer.startSession(atSourceTime: .zero)

        let playSeconds = last.time - first.time
        let playFrames = Int(playSeconds * Double(framesPerSecond))
        let finalFrames = Int(finalSeconds * Double(framesPerSecond))
        let ending = finalPlacements(job)
        for index in 0..<(playFrames + finalFrames) {
            while shouldPause() { try? await Task.sleep(for: .milliseconds(400)) }
            if Task.isCancelled { writer.cancelWriting(); return false }
            let time = Double(index) / Double(framesPerSecond)
            let figures = index < playFrames
                ? playFigures(job, at: first.time + time)
                : finalFigures(ending, job: job, time: time - playSeconds)
            guard let buffer = render(figures: figures, moment: job.moment, time: time, adaptor: adaptor) else { continue }
            while !input.isReadyForMoreMediaData { try? await Task.sleep(for: .milliseconds(5)) }
            adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(index), timescale: CMTimeScale(framesPerSecond)))
            if index % 4 == 0 { await Task.yield() }
        }
        input.markAsFinished()
        await writer.finishWriting()
        return writer.status == .completed
    }

    // MARK: - Quadros

    /// Os bonecos num instante da partida (posição real de cada jogador, ajustada ao recorte vertical).
    static func playFigures(_ job: AvatarVideoJob, at time: Double) -> [AvatarFigure] {
        guard let frame = job.frames.last(where: { $0.time <= time }) ?? job.frames.first else { return [] }
        return job.players.compactMap { player in
            guard let joints = frame.figures[player.slot] else { return nil }
            var mapped: [String: CGPoint] = [:]
            for (key, point) in joints where point.count == 2 {
                mapped[key] = CGPoint(x: (point[0] * job.aspect - job.framing.minX) / job.framing.width,
                                      y: (point[1] - job.framing.minY) / job.framing.height)
            }
            var figure = AvatarFigure(joints: mapped, colorHex: player.colorHex, name: player.name)
            figure.labelScale = 0.55
            return figure
        }
    }

    /// Onde cada jogador fica na cena final: espalhados, na ordem em que estavam da esquerda para a direita.
    static func finalPlacements(_ job: AvatarVideoJob) -> [(player: AvatarVideoPlayer, x: Double)] {
        let recent = job.frames.suffix(12)
        let ordered = job.players.sorted { meanX($0.slot, in: recent) < meanX($1.slot, in: recent) }
        return ordered.enumerated().map { index, player in
            (player, ordered.count == 1 ? 0.5 : 0.17 + 0.66 * Double(index) / Double(ordered.count - 1))
        }
    }

    private static func meanX(_ slot: ChildSlot, in frames: ArraySlice<PoseFrame>) -> Double {
        let xs = frames.compactMap { $0.figures[slot]?["n"]?.first }
        return xs.isEmpty ? 0.5 : xs.reduce(0, +) / Double(xs.count)
    }

    static func finalFigures(_ placements: [(player: AvatarVideoPlayer, x: Double)], job: AvatarVideoJob, time: Double) -> [AvatarFigure] {
        let count = placements.count
        let scale = count <= 1 ? 0.85 : (count == 2 ? 0.7 : (count == 3 ? 0.56 : 0.45))
        let aspect = size.width / size.height
        return placements.map { placement in
            let win = placement.player.isWinner
            let spec = win ? AvatarPoses.dance(time) : AvatarPoses.sad(time)
            var figure = AvatarFigure.player(name: placement.player.name, colorHex: placement.player.colorHex, x: placement.x, spec: spec,
                                             mood: win ? .win : .sad, crown: win, aspect: aspect, scale: scale, floor: 0.72)
            figure.labelScale = 0.55
            return figure
        }
    }

    // MARK: - Desenho

    private struct FrameView: View {
        let figures: [AvatarFigure]
        let moment: Moment
        let time: Double

        var body: some View {
            ZStack {
                LinearGradient(colors: [Color(hex: "#3A2A6B"), Color(hex: "#1B1433")], startPoint: .top, endPoint: .bottom)
                Canvas { ctx, canvasSize in
                    let box = CGRect(origin: .zero, size: canvasSize)
                    for figure in figures { AvatarRenderer(figure: figure, box: box, time: time).draw(in: &ctx) }
                }
                MomentOverlay(moment: moment)
            }
            .frame(width: AvatarVideoExporter.layoutSize.width, height: AvatarVideoExporter.layoutSize.height)
        }
    }

    private static func render(figures: [AvatarFigure], moment: Moment, time: Double,
                               adaptor: AVAssetWriterInputPixelBufferAdaptor) -> CVPixelBuffer? {
        let renderer = ImageRenderer(content: FrameView(figures: figures, moment: moment, time: time))
        renderer.scale = size.width / layoutSize.width
        guard let image = renderer.cgImage, let pool = adaptor.pixelBufferPool else { return nil }
        var buffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
        guard let buffer else { return nil }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: Int(size.width), height: Int(size.height),
                                      bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        else { return nil }
        context.draw(image, in: CGRect(origin: .zero, size: size))
        return buffer
    }
}
