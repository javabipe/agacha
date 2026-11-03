import AganhaCore
@testable import AganhaVision
import CoreGraphics
import Foundation
import Testing

@Suite struct PositioningCheckTests {
    private func analysis(_ skeletons: [Skeleton]) -> FrameAnalysis {
        PosePipeline().analyze(skeletons: skeletons, timestamp: 1, imageSize: CGSize(width: 1280, height: 720))
    }

    private func full(centerX: Double) -> Skeleton { makeSkeleton(centerX: centerX) }

    private func removing(_ names: [JointName], from skeleton: Skeleton) -> Skeleton {
        var copy = skeleton
        for name in names { copy.joints[name] = nil }
        return copy
    }

    @Test func fullBodyPeopleAreReady() {
        let report = PositioningCheck.evaluate(analysis([full(centerX: 0.3), full(centerX: 0.7)]))
        #expect(report.allReady)
        #expect(report.people.map(\.slot) == [0, 1])
        #expect(report.readySlots == [0, 1])
    }

    @Test func soloModeAcceptsASinglePerson() {
        let one = analysis([full(centerX: 0.5)])
        #expect(PositioningCheck.evaluate(one, minPlayers: 1).allReady)
        #expect(!PositioningCheck.evaluate(one).allReady)
        #expect(!PositioningCheck.evaluate(analysis([]), minPlayers: 1).allReady)
    }

    @Test func needsAtLeastTwoPlayers() {
        #expect(!PositioningCheck.evaluate(analysis([full(centerX: 0.5)])).allReady)
        #expect(!PositioningCheck.evaluate(analysis([])).allReady)
    }

    @Test func missingNoseIsNoHead() {
        let noHead = removing([.nose], from: full(centerX: 0.7))
        let report = PositioningCheck.evaluate(analysis([full(centerX: 0.3), noHead]))
        #expect(report.firstProblem?.issue == .noHead)
        #expect(report.firstProblem?.slot == 1)
        #expect(!report.allReady)
    }

    @Test func missingAnklesIsNoFeet() {
        let noFeet = removing([.leftAnkle, .rightAnkle], from: full(centerX: 0.3))
        let report = PositioningCheck.evaluate(analysis([noFeet, full(centerX: 0.7)]))
        #expect(report.firstProblem?.issue == .noFeet)
    }

    @Test func jointsAtTheFrameEdgeAreCutOff() {
        var cut = full(centerX: 0.3)
        cut.joints[.leftAnkle]?.y = 0.995
        let report = PositioningCheck.evaluate(analysis([cut, full(centerX: 0.7)]))
        #expect(report.firstProblem?.issue == .cutOff)
    }

    @Test func lowConfidenceCountsAsMissing() {
        var weak = full(centerX: 0.3)
        weak.joints[.nose]?.confidence = 0.1
        let report = PositioningCheck.evaluate(analysis([weak, full(centerX: 0.7)]))
        #expect(report.firstProblem?.issue == .noHead)
    }

    @Test func bothWristsAboveNoseIsRaisingArms() {
        var raised = full(centerX: 0.3)
        raised.joints[.leftWrist] = Joint(x: 0.25, y: 0.1, confidence: 0.9)
        raised.joints[.rightWrist] = Joint(x: 0.35, y: 0.1, confidence: 0.9)
        var oneArm = full(centerX: 0.7)
        oneArm.joints[.leftWrist] = Joint(x: 0.65, y: 0.1, confidence: 0.9)
        oneArm.joints[.rightWrist] = Joint(x: 0.75, y: 0.6, confidence: 0.9)
        let report = PositioningCheck.evaluate(analysis([raised, oneArm]))
        #expect(report.people[0].raisingBothArms)
        #expect(!report.people[1].raisingBothArms)
        #expect(report.anyRaisingBothArms)
    }

    @Test func extraPeopleAreCountedButNotChecked() {
        let skeletons = (0..<7).map { full(centerX: 0.1 + Double($0) * 0.12) }
        let report = PositioningCheck.evaluate(analysis(skeletons))
        #expect(report.people.count == 6)
        #expect(report.extraPeople == 1)
    }
}
