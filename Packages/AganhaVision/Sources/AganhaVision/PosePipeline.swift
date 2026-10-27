import AganhaCore
import CoreGraphics
import CoreVideo
import Foundation
import os

public struct TrackedPerson: Sendable, Identifiable {
    /// nil = pessoa extra (além das 6 vagas).
    public let slot: ChildSlot?
    public let skeleton: Skeleton
    public let reading: PostureReading
    public let id: Int

    public init(id: Int, slot: ChildSlot?, skeleton: Skeleton, reading: PostureReading) {
        self.id = id
        self.slot = slot
        self.skeleton = skeleton
        self.reading = reading
    }
}

public struct FrameAnalysis: Sendable {
    public let timestamp: TimeInterval
    public let imageSize: CGSize
    public let people: [TrackedPerson]
    /// Tempo gasto só no Vision, em ms.
    public let detectionMs: Double
    /// Tempo total do quadro (Vision + Tracker + classificação), em ms.
    public let latencyMs: Double
    /// Quadros processados por segundo (janela de 1 s).
    public let fps: Double

    public init(timestamp: TimeInterval, imageSize: CGSize, people: [TrackedPerson],
                detectionMs: Double, latencyMs: Double, fps: Double) {
        self.timestamp = timestamp
        self.imageSize = imageSize
        self.people = people
        self.detectionMs = detectionMs
        self.latencyMs = latencyMs
        self.fps = fps
    }
}

/// Vision → Tracker → PostureClassifier por vaga. Deve ser chamado de uma única fila (a da câmera);
/// `tuning` e `requestReset` podem ser mexidos de qualquer thread.
public final class PosePipeline: @unchecked Sendable {
    private let detector = PoseDetector()
    private var tracker = Tracker()
    private var classifiers: [ChildSlot: PostureClassifier] = [:]
    private var processedTimes: [TimeInterval] = []
    private let logger = Logger(subsystem: "br.com.agacha.vision", category: "pipeline")

    private let lock = NSLock()
    private var _tuning = PostureTuning.normal
    private var _resetRequested = false

    public init() {}

    public var tuning: PostureTuning {
        get { lock.withLock { _tuning } }
        set { lock.withLock { _tuning = newValue } }
    }

    /// Zera vagas e calibrações no próximo quadro.
    public func requestReset() {
        lock.withLock { _resetRequested = true }
    }

    /// Caminho da câmera.
    public func process(pixelBuffer: CVPixelBuffer, timestamp: TimeInterval) -> FrameAnalysis {
        let start = DispatchTime.now().uptimeNanoseconds
        let skeletons: [Skeleton]
        do {
            skeletons = try detector.detect(in: pixelBuffer)
        } catch {
            logger.error("Vision falhou: \(error.localizedDescription, privacy: .public)")
            skeletons = []
        }
        let detectionMs = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
        let size = CGSize(width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))
        return analyze(skeletons: skeletons, timestamp: timestamp, imageSize: size,
                       detectionMs: detectionMs, startedAt: start)
    }

    /// Caminho dos testes/fixtures: esqueletos já detectados.
    public func analyze(skeletons: [Skeleton], timestamp: TimeInterval, imageSize: CGSize,
                        detectionMs: Double = 0, startedAt: UInt64? = nil) -> FrameAnalysis {
        let (tuning, shouldReset) = lock.withLock {
            let state = (_tuning, _resetRequested)
            _resetRequested = false
            return state
        }
        if shouldReset {
            tracker.reset()
            classifiers = [:]
        }

        let slots = tracker.assign(to: skeletons)
        var seen = Set<ChildSlot>()
        var people: [TrackedPerson] = []
        for (index, skeleton) in skeletons.enumerated() {
            if let slot = slots[index] {
                seen.insert(slot)
                var classifier = classifiers[slot] ?? PostureClassifier()
                let reading = classifier.update(skeleton: skeleton, at: timestamp, tuning: tuning)
                classifiers[slot] = classifier
                people.append(TrackedPerson(id: slot, slot: slot, skeleton: skeleton, reading: reading))
            } else {
                let reading = PostureReading(posture: .unknown, crouchIndex: nil, isCalibrated: false)
                people.append(TrackedPerson(id: 100 + index, slot: nil, skeleton: skeleton, reading: reading))
            }
        }
        // Vagas sem esqueleto neste quadro continuam correndo o relógio de "sumiu".
        for slot in classifiers.keys where !seen.contains(slot) {
            _ = classifiers[slot]?.update(skeleton: nil, at: timestamp, tuning: tuning)
        }

        processedTimes.append(timestamp)
        processedTimes.removeAll { timestamp - $0 > 1 }
        let fps = Double(processedTimes.count)
        let latency = startedAt.map { Double(DispatchTime.now().uptimeNanoseconds - $0) / 1_000_000 } ?? detectionMs

        return FrameAnalysis(timestamp: timestamp, imageSize: imageSize, people: people,
                             detectionMs: detectionMs, latencyMs: latency, fps: fps)
    }
}
