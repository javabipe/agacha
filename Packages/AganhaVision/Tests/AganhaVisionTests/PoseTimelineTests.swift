import AganhaCore
@testable import AganhaVision
import CoreGraphics
import Testing

@Suite struct PoseTimelineTests {
    private func analysis(at time: Double, x: Double = 0.5, slot: ChildSlot? = 0) -> FrameAnalysis {
        let skeleton = Skeleton(joints: [
            .nose: Joint(x: x, y: 0.2, confidence: 0.9), .leftAnkle: Joint(x: x - 0.02, y: 0.9, confidence: 0.9),
            .rightAnkle: Joint(x: x + 0.02, y: 0.9, confidence: 0.1)
        ])
        let person = TrackedPerson(id: 1, slot: slot, skeleton: skeleton,
                                   reading: PostureReading(posture: .standing, crouchIndex: 0, isCalibrated: true))
        return FrameAnalysis(timestamp: time, imageSize: CGSize(width: 1280, height: 960), people: [person],
                             detectionMs: 1, latencyMs: 1, fps: 30)
    }

    @Test func keepsAboutTenToTwelveFramesPerSecondAndSkipsLowConfidenceJoints() {
        var timeline = PoseTimeline()
        for index in 0..<90 { timeline.append(analysis(at: Double(index) / 30)) }   // 3 s a 30 quadros/s
        #expect((28...37).contains(timeline.frames.count))
        #expect(timeline.frames[0].figures[0]?["n"] == [0.5, 0.2])
        #expect(timeline.frames[0].figures[0]?["ra"] == nil)
        #expect(abs(timeline.aspect - 4.0 / 3.0) < 1e-9)
    }

    @Test func extraPeopleWithoutASlotAreIgnored() {
        var timeline = PoseTimeline()
        timeline.append(analysis(at: 0, slot: nil))
        #expect(timeline.frames.isEmpty)
    }

    @Test func dropsFramesOlderThanTheLimit() {
        var timeline = PoseTimeline()
        for second in 0...90 { timeline.append(analysis(at: Double(second))) }
        #expect(timeline.duration <= PoseTimeline.maxSeconds)
        #expect(timeline.frames.count <= Int(PoseTimeline.maxSeconds) + 1)
    }

    @Test func framingContainsEveryPlayerAndMatchesTheTargetAspect() throws {
        var timeline = PoseTimeline()
        timeline.append(analysis(at: 0, x: 0.2))
        timeline.append(analysis(at: 1, x: 0.8))
        let frame = try #require(timeline.framing(targetAspect: 9.0 / 16.0))
        #expect(abs(frame.aspect - 9.0 / 16.0) < 1e-9)
        for x in [0.2, 0.8] {
            let px = x * timeline.aspect
            #expect(px >= frame.minX && px <= frame.minX + frame.width)
        }
        #expect(0.2 >= frame.minY && 0.9 <= frame.minY + frame.height)
    }

    @Test func clearEmptiesEverything() {
        var timeline = PoseTimeline()
        timeline.append(analysis(at: 0))
        timeline.clear()
        #expect(timeline.frames.isEmpty && timeline.framing(targetAspect: 0.5) == nil)
    }
}
