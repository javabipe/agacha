@testable import AganhaCore
import Testing

@Suite struct ModelsTests {
    @Test func postureSampleKeepsValues() {
        let sample = PostureSample(childSlot: 2, posture: .crouching, timestamp: 1.5)
        #expect(sample.childSlot == 2)
        #expect(sample.posture == .crouching)
        #expect(sample.timestamp == 1.5)
    }

    @Test func maxChildrenIsSix() {
        #expect(GameLimits.maxChildren == 6)
    }
}
