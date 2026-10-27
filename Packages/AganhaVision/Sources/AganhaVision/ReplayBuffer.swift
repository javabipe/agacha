import AganhaCore
import Foundation

/// Últimos `duration` segundos de esqueletos por vaga (nunca imagens), para o replay da eliminação.
public struct ReplayBuffer: Sendable {
    public struct Entry: Sendable, Equatable {
        public let timestamp: TimeInterval
        public let skeletons: [ChildSlot: Skeleton]

        public init(timestamp: TimeInterval, skeletons: [ChildSlot: Skeleton]) {
            self.timestamp = timestamp
            self.skeletons = skeletons
        }
    }

    public let duration: TimeInterval
    public private(set) var entries: [Entry] = []

    public init(duration: TimeInterval = 2) {
        self.duration = duration
    }

    public mutating func append(_ analysis: FrameAnalysis) {
        var skeletons: [ChildSlot: Skeleton] = [:]
        for person in analysis.people {
            if let slot = person.slot { skeletons[slot] = person.skeleton }
        }
        entries.append(Entry(timestamp: analysis.timestamp, skeletons: skeletons))
        entries.removeAll { analysis.timestamp - $0.timestamp > duration }
    }

    public mutating func clear() {
        entries = []
    }

    /// `count` quadros igualmente espaçados em que a vaga aparece (ex.: os 3 quadros do replay).
    public func snapshots(for slot: ChildSlot, count: Int) -> [Skeleton] {
        let frames = entries.compactMap { $0.skeletons[slot] }
        guard count > 0, !frames.isEmpty else { return [] }
        guard frames.count > count else { return frames }
        return (0..<count).map { frames[$0 * (frames.count - 1) / max(count - 1, 1)] }
    }
}
