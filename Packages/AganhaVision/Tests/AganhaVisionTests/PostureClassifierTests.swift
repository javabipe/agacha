import AganhaCore
@testable import AganhaVision
import Testing

@Suite struct PostureClassifierTests {
    private let tuning = PostureTuning.normal

    /// Alimenta `seconds` de quadros iguais e devolve a última leitura e o tempo final.
    private func feed(_ classifier: inout PostureClassifier, skeleton: Skeleton?, from start: Double,
                      seconds: Double) -> (reading: PostureReading, end: Double) {
        var time = start
        var reading = PostureReading(posture: .unknown, crouchIndex: nil, isCalibrated: false)
        let frames = Int((seconds / frameStep).rounded())
        for _ in 0..<frames {
            reading = classifier.update(skeleton: skeleton, at: time, tuning: tuning)
            time += frameStep
        }
        return (reading, time)
    }

    @Test func calibratesThenReportsStanding() {
        var classifier = PostureClassifier()
        let result = feed(&classifier, skeleton: makeSkeleton(), from: 0, seconds: 0.5)
        #expect(result.reading.posture == .standing)
        #expect(result.reading.isCalibrated)
        #expect(abs(result.reading.crouchIndex ?? 1) < 0.01)
    }

    @Test func crouchNeedsDebounce() {
        var classifier = PostureClassifier()
        var t = feed(&classifier, skeleton: makeSkeleton(), from: 0, seconds: 0.5).end
        // Agachado (queda de 0.2 / tronco 0.25 = índice 0.8) por menos que o debounce: ainda em pé.
        let brief = feed(&classifier, skeleton: makeSkeleton(hipDrop: 0.2), from: t, seconds: 0.1)
        #expect(brief.reading.posture == .standing)
        t = brief.end
        let sustained = feed(&classifier, skeleton: makeSkeleton(hipDrop: 0.2), from: t, seconds: 0.3)
        #expect(sustained.reading.posture == .crouching)
        #expect((sustained.reading.crouchIndex ?? 0) > 0.7)
    }

    @Test func hysteresisDeadZoneKeepsPosture() {
        var classifier = PostureClassifier()
        var t = feed(&classifier, skeleton: makeSkeleton(), from: 0, seconds: 0.5).end
        t = feed(&classifier, skeleton: makeSkeleton(hipDrop: 0.2), from: t, seconds: 0.4).end
        // Índice 0.32 (entre 0.25 e 0.45): permanece agachado.
        let dead = feed(&classifier, skeleton: makeSkeleton(hipDrop: 0.08), from: t, seconds: 0.5)
        #expect(dead.reading.posture == .crouching)
        // Volta ao topo: vira em pé.
        let back = feed(&classifier, skeleton: makeSkeleton(), from: dead.end, seconds: 0.4)
        #expect(back.reading.posture == .standing)
    }

    @Test func missingPersonBecomesUnknownAfterTimeout() {
        var classifier = PostureClassifier()
        let t = feed(&classifier, skeleton: makeSkeleton(), from: 0, seconds: 0.5).end
        let brief = feed(&classifier, skeleton: nil, from: t, seconds: 0.2)
        #expect(brief.reading.posture == .standing)
        let lost = feed(&classifier, skeleton: nil, from: brief.end, seconds: 0.3)
        #expect(lost.reading.posture == .unknown)
    }

    @Test func lowConfidenceIsTreatedAsMissing() {
        var classifier = PostureClassifier()
        let t = feed(&classifier, skeleton: makeSkeleton(), from: 0, seconds: 0.5).end
        let blurry = feed(&classifier, skeleton: makeSkeleton(confidence: 0.1), from: t, seconds: 0.6)
        #expect(blurry.reading.posture == .unknown)
    }

    @Test func crouchIndexIsIndependentOfDistance() {
        // Mesma pose, esqueleto reduzido à metade (pessoa mais longe): mesmo índice.
        func scaled(_ skeleton: Skeleton, by factor: Double) -> Skeleton {
            Skeleton(joints: skeleton.joints.mapValues {
                Joint(x: 0.5 + ($0.x - 0.5) * factor, y: 0.5 + ($0.y - 0.5) * factor, confidence: $0.confidence)
            })
        }
        var near = PostureClassifier()
        var far = PostureClassifier()
        var t = feed(&near, skeleton: makeSkeleton(), from: 0, seconds: 0.5).end
        _ = feed(&far, skeleton: scaled(makeSkeleton(), by: 0.5), from: 0, seconds: 0.5)
        let nearIndex = feed(&near, skeleton: makeSkeleton(hipDrop: 0.2), from: t, seconds: 0.3).reading.crouchIndex
        t = 0.5
        let farIndex = feed(&far, skeleton: scaled(makeSkeleton(hipDrop: 0.2), by: 0.5), from: t, seconds: 0.3).reading.crouchIndex
        #expect(abs((nearIndex ?? 0) - (farIndex ?? 99)) < 0.05)
    }
}
