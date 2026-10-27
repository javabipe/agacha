@testable import AganhaVision
import CoreGraphics
import Foundation
import Testing

@Suite struct TrackerAndPipelineTests {
    @Test func newPeopleGetSlotsLeftToRight() {
        var tracker = Tracker()
        let skeletons = [makeSkeleton(centerX: 0.8), makeSkeleton(centerX: 0.2), makeSkeleton(centerX: 0.5)]
        let slots = tracker.assign(to: skeletons)
        #expect(slots == [2, 0, 1])
    }

    @Test func slotsSurviveSmallMovementAndReordering() {
        var tracker = Tracker()
        _ = tracker.assign(to: [makeSkeleton(centerX: 0.2), makeSkeleton(centerX: 0.7)])
        // Mesma gente, ordem trocada na lista e levemente deslocada.
        let slots = tracker.assign(to: [makeSkeleton(centerX: 0.72), makeSkeleton(centerX: 0.18)])
        #expect(slots == [1, 0])
    }

    @Test func seventhPersonIsExtra() {
        var tracker = Tracker()
        let skeletons = (0..<7).map { makeSkeleton(centerX: 0.1 + Double($0) * 0.12) }
        let slots = tracker.assign(to: skeletons)
        #expect(slots.compactMap { $0 }.count == 6)
        #expect(slots.filter { $0 == nil }.count == 1)
    }

    @Test func resetFreesSlots() {
        var tracker = Tracker()
        _ = tracker.assign(to: [makeSkeleton(centerX: 0.2)])
        tracker.reset()
        #expect(tracker.assign(to: [makeSkeleton(centerX: 0.9)]) == [0])
    }

    @Test func pipelineClassifiesTwoChildrenIndependently() {
        let pipeline = PosePipeline()
        let size = CGSize(width: 720, height: 1280)
        var time = 0.0
        var last: FrameAnalysis?
        // 0.5 s calibrando, depois a criança da direita agacha por 0.4 s.
        for frame in 0..<27 {
            let right = makeSkeleton(centerX: 0.75, hipDrop: frame < 15 ? 0 : 0.2)
            last = pipeline.analyze(skeletons: [makeSkeleton(centerX: 0.25), right], timestamp: time, imageSize: size)
            time += frameStep
        }
        let bySlot = Dictionary(uniqueKeysWithValues: (last?.people ?? []).compactMap { person in
            person.slot.map { ($0, person.reading.posture) }
        })
        #expect(bySlot[0] == .standing)
        #expect(bySlot[1] == .crouching)
    }

    @Test func fixtureRoundTrips() throws {
        let analysis = PosePipeline().analyze(skeletons: [makeSkeleton()], timestamp: 3, imageSize: CGSize(width: 720, height: 1280))
        let fixture = SkeletonFixture(
            createdAt: Date(timeIntervalSince1970: 0), imageWidth: 720, imageHeight: 1280, tuning: .normal,
            frames: [SkeletonFixture.Frame(analysis: analysis, startTime: 1)]
        )
        let decoded = try SkeletonFixture.decode(try fixture.encoded())
        #expect(decoded.frames.count == 1)
        #expect(decoded.frames[0].t == 2)
        #expect(decoded.frames[0].people[0].skeleton == makeSkeleton())
    }
}
