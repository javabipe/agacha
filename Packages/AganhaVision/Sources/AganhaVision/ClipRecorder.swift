import AVFoundation
import CoreMedia
import CoreVideo
import Foundation
import ImageIO
import os
import UniformTypeIdentifiers

/// O vídeo do replay (uma composição de AVFoundation) para passar entre filas; só é lido, nunca alterado.
public struct ReplayAsset: @unchecked Sendable {
    public let asset: AVAsset

    public init(_ asset: AVAsset) {
        self.asset = asset
    }
}

/// Grava, em arquivos temporários curtos, os últimos segundos da câmera para o replay de "Alguém errou".
/// Tudo fica na pasta temporária do app, é apagado ao fim do replay, ao sair da partida e na próxima abertura.
/// Nada é enviado nem guardado de forma permanente.
public final class ClipRecorder: @unchecked Sendable {
    /// Duração de cada pedaço gravado (s).
    public static let segmentSeconds = 2.0
    /// Pedaços finalizados mantidos (os mais velhos são apagados).
    public static let keptSegments = 4

    private struct Segment {
        let url: URL
        let start: Double
        var end: Double
    }

    private let directory: URL
    private let lock = NSLock()

    private var recording = false
    private var frozen = false
    private var writer: AVAssetWriter?
    private var input: AVAssetWriterInput?
    private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var current: Segment?
    private var finished: [Segment] = []
    private var pendingFinishes = 0
    private var counter = 0
    /// Muda a cada `stop`/`resume`/`removeAll`; pedaços que terminam de gravar depois disso são descartados.
    private var generation = 0
    /// Depois de uma falha ao abrir o arquivo, espera um pouco antes de tentar de novo.
    private var nextOpenAttempt = 0.0
    private let logger = Logger(subsystem: "br.com.agacha.vision", category: "clips")

    public init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.temporaryDirectory.appending(path: "agacha-replay", directoryHint: .isDirectory)
        wipe()
    }

    deinit {
        wipe()
    }

    /// Começa a gravar os quadros recebidos em `append`.
    public func start() {
        lock.withLock {
            recording = true
            frozen = false
        }
    }

    /// Para de gravar e apaga tudo.
    public func stop() {
        lock.withLock {
            recording = false
            frozen = false
            generation += 1
            abandonCurrent()
            finished = []
        }
        wipe()
    }

    /// Chamado a cada quadro, na fila da câmera.
    public func append(_ buffer: CVPixelBuffer, at time: Double) {
        lock.lock()
        defer { lock.unlock() }
        guard recording, !frozen else { return }
        if let current, time - current.start >= Self.segmentSeconds { closeCurrent() }
        if writer == nil {
            guard time >= nextOpenAttempt else { return }
            openSegment(for: buffer, at: time)
        }
        guard let input, let adaptor, input.isReadyForMoreMediaData else { return }
        if adaptor.append(buffer, withPresentationTime: CMTime(seconds: time, preferredTimescale: 600)) {
            current?.end = time
        }
    }

    /// Congela a gravação e devolve os últimos `seconds` segundos como vídeo para tocar.
    /// Chame `resume()` quando terminar de mostrar (isso apaga os arquivos).
    public func capture(seconds: Double) async -> AVAsset? {
        let generationAtStart = lock.withLock { () -> Int in
            frozen = true
            closeCurrent()
            return generation
        }
        // Espera os pedaços em fechamento terminarem de ser gravados.
        for _ in 0..<75 {
            if lock.withLock({ pendingFinishes == 0 }) { break }
            try? await Task.sleep(for: .milliseconds(40))
        }
        let chosen = lock.withLock { () -> [Segment] in
            guard generation == generationAtStart else { return [] }
            var total = 0.0
            var picked: [Segment] = []
            for segment in finished.reversed() {
                picked.insert(segment, at: 0)
                total += segment.end - segment.start
                if total >= seconds { break }
            }
            return picked
        }
        return await Self.composition(of: chosen.map(\.url))
    }

    /// Tira quadros JPEG do replay (para a TV mostrar como a câmera: imagem após imagem, sem depender de codec de vídeo).
    /// Fica só na memória. Lista vazia se algo falhar.
    public func exportFrames(_ replay: ReplayAsset, framesPerSecond: Double = 10, maxWidth: Double = 640) async -> [Data] {
        let asset = replay.asset
        guard let duration = try? await asset.load(.duration), duration.isValid, duration.seconds > 0 else { return [] }
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxWidth, height: maxWidth)
        let tolerance = CMTime(seconds: 0.5 / framesPerSecond, preferredTimescale: 600)
        generator.requestedTimeToleranceBefore = tolerance
        generator.requestedTimeToleranceAfter = tolerance
        let times = (0..<Int(duration.seconds * framesPerSecond)).map {
            CMTime(seconds: Double($0) / framesPerSecond, preferredTimescale: 600)
        }
        var frames: [(time: Double, data: Data)] = []
        for await result in generator.images(for: times) {
            if case let .success(requested, image, _) = result, let data = Self.jpeg(image) {
                frames.append((requested.seconds, data))
            }
        }
        return frames.sorted { $0.time < $1.time }.map(\.data)
    }

    private static func jpeg(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.6] as CFDictionary)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }

    /// Junta o replay num único MP4 (sem recodificar) em `url`, para guardar junto com o momento. O arquivo não fica na pasta
    /// temporária do gravador, então sobrevive a `resume()`/`stop()`.
    public func exportMP4(_ replay: ReplayAsset, to url: URL) async -> Bool {
        try? FileManager.default.removeItem(at: url)
        guard let session = AVAssetExportSession(asset: replay.asset, presetName: AVAssetExportPresetPassthrough) else { return false }
        if #available(iOS 18.0, macOS 15.0, tvOS 18.0, *) {
            do {
                try await session.export(to: url, as: .mp4)
                return true
            } catch {
                return false
            }
        }
        session.outputURL = url
        session.outputFileType = .mp4
        await withCheckedContinuation { continuation in
            session.exportAsynchronously { continuation.resume() }
        }
        return session.status == .completed
    }

    /// Terminou o replay: apaga o que foi gravado e volta a gravar.
    public func resume() {
        lock.withLock {
            generation += 1
            abandonCurrent()
            finished = []
            frozen = false
        }
        wipe()
    }

    public func removeAll() {
        lock.withLock {
            generation += 1
            abandonCurrent()
            finished = []
        }
        wipe()
    }

    /// Quantos pedaços estão guardados no disco agora (para testes).
    public var storedFileCount: Int {
        (try? FileManager.default.contentsOfDirectory(atPath: directory.path).count) ?? 0
    }

    // MARK: - Privado (chamar com o lock)

    private func openSegment(for buffer: CVPixelBuffer, at time: Double) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                    attributes: [.protectionKey: FileProtectionType.complete])
            counter += 1
            let url = directory.appending(path: "clip-\(counter).mp4")
            let newWriter = try AVAssetWriter(outputURL: url, fileType: .mp4)
            let settings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: CVPixelBufferGetWidth(buffer),
                AVVideoHeightKey: CVPixelBufferGetHeight(buffer),
                AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 2_500_000, AVVideoMaxKeyFrameIntervalKey: 30]
            ]
            let newInput = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
            newInput.expectsMediaDataInRealTime = true
            guard newWriter.canAdd(newInput) else { throw CocoaError(.fileWriteUnknown) }
            newWriter.add(newInput)
            // O adaptador precisa existir antes de `startWriting()` (senão o AVFoundation aborta).
            let newAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: newInput, sourcePixelBufferAttributes: nil)
            guard newWriter.startWriting() else { throw newWriter.error ?? CocoaError(.fileWriteUnknown) }
            newWriter.startSession(atSourceTime: CMTime(seconds: time, preferredTimescale: 600))
            writer = newWriter
            input = newInput
            adaptor = newAdaptor
            current = Segment(url: url, start: time, end: time)
        } catch {
            writer = nil
            nextOpenAttempt = time + 1
            logger.error("Não foi possível abrir o arquivo do replay: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func closeCurrent() {
        guard let writer, let input, let segment = current else { return }
        let generationAtClose = generation
        self.writer = nil
        self.input = nil
        adaptor = nil
        current = nil
        input.markAsFinished()
        pendingFinishes += 1
        writer.finishWriting { [weak self] in
            guard let self else { return }
            lock.withLock {
                pendingFinishes -= 1
                if writer.status == .completed, generationAtClose == generation {
                    finished.append(segment)
                    while finished.count > Self.keptSegments {
                        try? FileManager.default.removeItem(at: finished.removeFirst().url)
                    }
                } else {
                    try? FileManager.default.removeItem(at: segment.url)
                }
            }
        }
    }

    private func abandonCurrent() {
        writer?.cancelWriting()
        writer = nil
        input = nil
        adaptor = nil
        current = nil
    }

    private func wipe() {
        try? FileManager.default.removeItem(at: directory)
    }

    private static func composition(of urls: [URL]) async -> AVAsset? {
        guard !urls.isEmpty else { return nil }
        let composition = AVMutableComposition()
        guard let track = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            return nil
        }
        var cursor = CMTime.zero
        for url in urls {
            let asset = AVURLAsset(url: url)
            guard let source = try? await asset.loadTracks(withMediaType: .video).first,
                  let duration = try? await asset.load(.duration), duration.isValid, duration > .zero
            else { continue }
            if (try? track.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: source, at: cursor)) != nil {
                cursor = CMTimeAdd(cursor, duration)
            }
        }
        return cursor > .zero ? composition : nil
    }
}
