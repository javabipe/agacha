import AganhaVision
import Foundation
import Observation
import os

/// Estado do spike da Fase 0: câmera → pipeline → HUD, painel de debug e gravação de fixture.
@MainActor
@Observable
final class SpikeModel {
    private(set) var analysis: FrameAnalysis?
    private(set) var cameraInfo: CameraInfo?
    private(set) var errorMessage: String?
    private(set) var isRecording = false
    private(set) var recordedFrameCount = 0
    private(set) var lastSavedFile: String?
    private(set) var avgDetectionMs: Double = 0

    var tuning = PostureTuning.normal {
        didSet { pipeline.tuning = tuning }
    }
    var notes = ""

    let camera = CameraSession()
    private let pipeline = PosePipeline()
    private let logger = Logger(subsystem: "br.com.agacha.app", category: "spike")

    private var recordingStart: TimeInterval?
    private var recordedFrames: [SkeletonFixture.Frame] = []
    private var recordedSize: (width: Double, height: Double) = (0, 0)
    private var detectionSamples: [Double] = []

    func start() async {
        let pipeline = pipeline
        let model = self
        camera.onFrame = { buffer, timestamp in
            let analysis = pipeline.process(pixelBuffer: buffer, timestamp: timestamp)
            Task { @MainActor in model.apply(analysis) }
        }
        do {
            cameraInfo = try await camera.start()
            camera.updateRotationCoordinator()
            errorMessage = nil
        } catch CameraError.denied {
            errorMessage = String(localized: "Permita o acesso à câmera em Ajustes para usar o Aganha.")
        } catch {
            errorMessage = String(localized: "Não foi possível iniciar a câmera.")
            logger.error("Câmera falhou: \(error.localizedDescription, privacy: .public)")
        }
    }

    func stop() {
        camera.stop()
    }

    /// Zera vagas e calibrações (todos em pé, de frente para a câmera).
    func recalibrate() {
        pipeline.requestReset()
    }

    func resetTuning() {
        tuning = .normal
    }

    func toggleRecording() {
        if isRecording { finishRecording() } else { startRecording() }
    }

    private func apply(_ analysis: FrameAnalysis) {
        self.analysis = analysis
        detectionSamples.append(analysis.detectionMs)
        if detectionSamples.count > 30 { detectionSamples.removeFirst() }
        avgDetectionMs = detectionSamples.reduce(0, +) / Double(detectionSamples.count)

        guard isRecording else { return }
        let start = recordingStart ?? analysis.timestamp
        recordingStart = start
        recordedSize = (analysis.imageSize.width, analysis.imageSize.height)
        recordedFrames.append(SkeletonFixture.Frame(analysis: analysis, startTime: start))
        recordedFrameCount = recordedFrames.count
    }

    private func startRecording() {
        recordedFrames = []
        recordedFrameCount = 0
        recordingStart = nil
        lastSavedFile = nil
        isRecording = true
    }

    private func finishRecording() {
        isRecording = false
        guard !recordedFrames.isEmpty else { return }
        let fixture = SkeletonFixture(
            createdAt: Date(), imageWidth: recordedSize.width, imageHeight: recordedSize.height,
            tuning: tuning, notes: notes, frames: recordedFrames
        )
        do {
            let stamp = Date().formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false)
                .timeSeparator(.omitted).dateSeparator(.omitted))
            let name = "fixture-\(stamp).json"
            let documents = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask,
                                                        appropriateFor: nil, create: true)
            try fixture.encoded().write(to: documents.appending(path: name), options: .atomic)
            lastSavedFile = name
        } catch {
            errorMessage = String(localized: "Não foi possível salvar a fixture.")
            logger.error("Salvar fixture falhou: \(error.localizedDescription, privacy: .public)")
        }
        recordedFrames = []
    }
}
