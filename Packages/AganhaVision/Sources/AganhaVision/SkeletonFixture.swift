import AganhaCore
import Foundation

/// Sequência gravada de esqueletos (nunca imagens), usada como fixture de teste offline.
public struct SkeletonFixture: Codable, Sendable {
    public struct Person: Codable, Sendable {
        public var slot: ChildSlot?
        public var skeleton: Skeleton
        /// O que o app classificou na hora da gravação (referência, não verdade absoluta).
        public var observedPosture: Posture
        public var observedCrouch: Double?

        public init(slot: ChildSlot?, skeleton: Skeleton, observedPosture: Posture, observedCrouch: Double?) {
            self.slot = slot
            self.skeleton = skeleton
            self.observedPosture = observedPosture
            self.observedCrouch = observedCrouch
        }
    }

    public struct Frame: Codable, Sendable {
        /// Segundos desde o início da gravação.
        public var t: Double
        public var people: [Person]

        public init(t: Double, people: [Person]) {
            self.t = t
            self.people = people
        }
    }

    public var version = 1
    public var createdAt: Date
    public var imageWidth: Double
    public var imageHeight: Double
    public var tuning: PostureTuning
    public var notes: String
    public var frames: [Frame]

    public init(createdAt: Date, imageWidth: Double, imageHeight: Double,
                tuning: PostureTuning, notes: String = "", frames: [Frame]) {
        self.createdAt = createdAt
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.tuning = tuning
        self.notes = notes
        self.frames = frames
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }

    public static func decode(_ data: Data) throws -> SkeletonFixture {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(SkeletonFixture.self, from: data)
    }
}

public extension SkeletonFixture.Frame {
    init(analysis: FrameAnalysis, startTime: TimeInterval) {
        self.init(
            t: analysis.timestamp - startTime,
            people: analysis.people.map {
                SkeletonFixture.Person(slot: $0.slot, skeleton: $0.skeleton,
                                       observedPosture: $0.reading.posture, observedCrouch: $0.reading.crouchIndex)
            }
        )
    }
}
