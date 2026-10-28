import AganhaCore
import Foundation

/// Mantém a identidade por "vaga" entre quadros (spec 6.2): centroide mais próximo, guloso.
public struct Tracker: Sendable {
    public let maxSlots: Int
    /// Distância máxima (em coordenadas normalizadas) para reaproveitar uma vaga.
    public let maxMatchDistance: Double
    /// Peso do deslocamento vertical na distância: agachar move o centro quase só em y,
    /// então y conta menos que x para não confundir "agachou" com "pessoa nova".
    public let verticalWeight: Double
    private var lastCentroid: [ChildSlot: Point2D] = [:]

    public init(maxSlots: Int = GameLimits.maxChildren, maxMatchDistance: Double = 0.3,
                verticalWeight: Double = 0.25) {
        self.maxSlots = maxSlots
        self.maxMatchDistance = maxMatchDistance
        self.verticalWeight = verticalWeight
    }

    public mutating func reset() {
        lastCentroid = [:]
    }

    /// Vagas já ocupadas alguma vez desde o último `reset`.
    public var occupiedSlots: [ChildSlot] {
        lastCentroid.keys.sorted()
    }

    /// Devolve, para cada esqueleto, a vaga associada (nil = "pessoa extra").
    /// Esqueletos novos recebem as vagas livres da esquerda para a direita.
    public mutating func assign(to skeletons: [Skeleton]) -> [ChildSlot?] {
        var result = [ChildSlot?](repeating: nil, count: skeletons.count)
        let centroids = skeletons.map(\.centroid)

        var candidates: [(distance: Double, index: Int, slot: ChildSlot)] = []
        for (index, centroid) in centroids.enumerated() {
            guard let centroid else { continue }
            for (slot, last) in lastCentroid {
                candidates.append((hypot(centroid.x - last.x, (centroid.y - last.y) * verticalWeight), index, slot))
            }
        }
        candidates.sort { $0.distance < $1.distance }

        var usedSlots = Set<ChildSlot>()
        for candidate in candidates where candidate.distance <= maxMatchDistance {
            guard result[candidate.index] == nil, !usedSlots.contains(candidate.slot) else { continue }
            result[candidate.index] = candidate.slot
            usedSlots.insert(candidate.slot)
        }

        var freeSlots = (0..<maxSlots).filter { lastCentroid[$0] == nil }
        let unmatched = centroids.indices
            .filter { result[$0] == nil && centroids[$0] != nil }
            .sorted { (centroids[$0]?.x ?? 0) < (centroids[$1]?.x ?? 0) }
        for index in unmatched where !freeSlots.isEmpty {
            result[index] = freeSlots.removeFirst()
        }

        for (index, slot) in result.enumerated() {
            if let slot, let centroid = centroids[index] { lastCentroid[slot] = centroid }
        }
        return result
    }
}
