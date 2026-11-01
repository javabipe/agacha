import AganhaVision
import Foundation
import Observation
import os

/// Jogador conhecido: nome e as impressões do rosto (só vetores, nunca imagens).
struct PlayerProfile: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var prints: [FacePrint]
    /// Variação entre as impressões guardadas (define quão rígido é o reconhecimento).
    var spread: Double
    let createdAt: Date
    var lastSeenAt: Date
}

/// Guarda os jogadores no aparelho (arquivo protegido, fora do backup). Nada sai do iPad.
@MainActor
@Observable
final class ProfileStore {
    static let maxPrintsPerProfile = 12
    static let consentKey = "faceConsent"

    private(set) var profiles: [PlayerProfile] = []
    private let fileURL: URL
    private let defaults: UserDefaults
    private let logger = Logger(subsystem: "br.com.agacha.app", category: "profiles")

    /// Autorização de um adulto para guardar rostos. nil = ainda não perguntou.
    var consent: Bool? {
        didSet {
            if let consent { defaults.set(consent, forKey: Self.consentKey) } else { defaults.removeObject(forKey: Self.consentKey) }
            if consent == false { deleteAll() }
        }
    }

    init(fileURL: URL? = nil, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.fileURL = fileURL ?? Self.defaultURL()
        consent = defaults.object(forKey: Self.consentKey) as? Bool
        load()
    }

    // MARK: - Reconhecimento

    struct Identification {
        let decision: FaceDecision
        let profile: PlayerProfile?
        /// Melhor distância e limite do melhor candidato (para o painel de detalhes).
        let debug: String
    }

    /// Compara as impressões vistas com os jogadores guardados (`ids` limita a quem comparar).
    func identify(_ probes: [FacePrint], among ids: Set<UUID>? = nil, excluding excluded: Set<UUID> = []) -> Identification {
        let pool = profiles.filter { (ids?.contains($0.id) ?? true) && !excluded.contains($0.id) }
        let candidates = pool.map { profile -> FaceCandidate in
            let distances = profile.prints.compactMap { saved in probes.compactMap { $0.distance(to: saved) }.min() }
            return FaceCandidate(id: profile.id.uuidString, distances: distances, spread: profile.spread)
        }
        let decision = FaceMatchPolicy.standard.decide(candidates)
        let best = candidates.compactMap { candidate in candidate.distances.min().map { (candidate, $0) } }.min { $0.1 < $1.1 }
        let debug = best.map { candidate, distance in
            let name = pool.first { $0.id.uuidString == candidate.id }?.name ?? "?"
            let limit = FaceMatchPolicy.standard.threshold(spread: candidate.spread)
            return "\(name): distância \(String(format: "%.2f", distance)) / limite \(String(format: "%.2f", limit))"
        } ?? "sem jogadores guardados"
        if case let .match(id, _) = decision {
            return Identification(decision: decision, profile: profiles.first { $0.id.uuidString == id }, debug: debug)
        }
        return Identification(decision: decision, profile: nil, debug: debug)
    }

    // MARK: - Alterações

    /// Cria o jogador, ou acrescenta as impressões se já existe alguém com esse nome.
    @discardableResult
    func upsert(name: String, prints: [FacePrint]) -> PlayerProfile? {
        guard consent == true else { return nil }
        if let index = profiles.firstIndex(where: { $0.name.lowercased() == name.lowercased() }) {
            merge(prints, into: index)
            return profiles[index]
        }
        let profile = PlayerProfile(id: UUID(), name: name, prints: Array(prints.suffix(Self.maxPrintsPerProfile)),
                                    spread: FaceMatchPolicy.spread(of: prints), createdAt: Date(), lastSeenAt: Date())
        profiles.append(profile)
        save()
        return profile
    }

    /// Acrescenta impressões de um reconhecimento confiável (o jogador "aprende" a variação do rosto).
    func addSamples(_ prints: [FacePrint], to id: UUID) {
        guard consent == true, let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        merge(prints, into: index)
    }

    func rename(_ id: UUID, to name: String) {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        profiles[index].name = name
        save()
    }

    func delete(_ id: UUID) {
        profiles.removeAll { $0.id == id }
        save()
    }

    func deleteAll() {
        profiles = []
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func merge(_ prints: [FacePrint], into index: Int) {
        var merged = profiles[index].prints + prints
        if merged.count > Self.maxPrintsPerProfile { merged = Array(merged.suffix(Self.maxPrintsPerProfile)) }
        profiles[index].prints = merged
        profiles[index].spread = FaceMatchPolicy.spread(of: merged)
        profiles[index].lastSeenAt = Date()
        save()
    }

    // MARK: - Arquivo

    private static func defaultURL() -> URL {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                 appropriateFor: nil, create: true)) ?? FileManager.default.temporaryDirectory
        return base.appending(path: "players.json")
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        do {
            profiles = try JSONDecoder().decode([PlayerProfile].self, from: data)
        } catch {
            logger.error("Não foi possível ler os jogadores: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(profiles)
            try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUnlessOpen])
            var url = fileURL
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try url.setResourceValues(values)
        } catch {
            logger.error("Não foi possível salvar os jogadores: \(error.localizedDescription, privacy: .public)")
        }
    }
}
