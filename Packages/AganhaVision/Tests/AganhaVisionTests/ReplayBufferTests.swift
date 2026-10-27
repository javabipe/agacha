@testable import AganhaVision
import CoreGraphics
import Foundation
import Testing

@Suite struct ReplayBufferTests {
    private func analysis(at time: TimeInterval) -> FrameAnalysis {
        PosePipeline().analyze(skeletons: [makeSkeleton()], timestamp: time, imageSize: CGSize(width: 720, height: 1280))
    }

    @Test func dropsEntriesOlderThanDuration() {
        var buffer = ReplayBuffer(duration: 2)
        for index in 0..<100 { buffer.append(analysis(at: Double(index) / 30)) }
        #expect(buffer.entries.count <= 61)
        #expect(buffer.entries.first.map { 99.0 / 30 - $0.timestamp <= 2 } == true)
    }

    @Test func snapshotsReturnsRequestedCount() {
        var buffer = ReplayBuffer()
        for index in 0..<30 { buffer.append(analysis(at: Double(index) / 30)) }
        #expect(buffer.snapshots(for: 0, count: 3).count == 3)
        #expect(buffer.snapshots(for: 5, count: 3).isEmpty)
    }
}
