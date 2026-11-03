import AganhaCore
import Foundation
import UIKit

/// Momentos salvos **só neste aparelho** (pasta do app, fora do backup): um pôster de avatares e as fotos reais ("shots")
/// de cada partida. Nada é enviado; o responsável pode apagar um momento ou todos.
private struct SavedPlayer: Codable {
    let name: String
    let colorHex: String
    let coins: Int
    let isWinner: Bool
    var girl: Bool?
}

private struct Saved: Codable {
    let id: UUID
    let date: Date
    let title: String
    let place: String
    let durationSeconds: Int
    let mode: GameMode
    let rounds: Int
    let fastestMs: Int?
    let players: [SavedPlayer]
    let posterFile: String?
    let shotFiles: [String]
    var videoFile: String?
    var clipFile: String?
}

struct MomentStore: Sendable {
    static let shared = MomentStore()
    private let root: URL

    init(root: URL? = nil) {
        let base = root ?? URL.applicationSupportDirectory.appending(path: "Moments", directoryHint: .isDirectory)
        self.root = base
    }

    // MARK: - Guardar

    /// Salva o momento (JSON, pôster de avatares e fotos reais). Devolve o momento já apontando para os arquivos.
    @discardableResult
    func save(_ moment: Moment, poster: Data?, shots: [Data], clip: URL? = nil, date: Date = Date()) -> Moment? {
        let folder = root.appending(path: moment.id.uuidString, directoryHint: .isDirectory)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true,
                                                    attributes: [.protectionKey: FileProtectionType.complete])
            var excluded = URLResourceValues()
            excluded.isExcludedFromBackup = true
            var mutableRoot = root
            try? mutableRoot.setResourceValues(excluded)
            var posterFile: String?
            if let poster {
                try poster.write(to: folder.appending(path: "poster.png"), options: .completeFileProtection)
                posterFile = "poster.png"
            }
            var shotFiles: [String] = []
            for (index, shot) in shots.enumerated() {
                let name = "shot-\(index + 1).jpg"
                try shot.write(to: folder.appending(path: name), options: .completeFileProtection)
                shotFiles.append(name)
            }
            var clipFile: String?
            if let clip {
                try FileManager.default.moveItem(at: clip, to: folder.appending(path: "replay-do-erro.mp4"))
                clipFile = "replay-do-erro.mp4"
            }
            let saved = Saved(id: moment.id, date: date, title: moment.title, place: moment.place,
                              durationSeconds: moment.durationSeconds, mode: moment.mode, rounds: moment.rounds,
                              fastestMs: moment.fastestMs,
                              players: moment.players.map {
                                  SavedPlayer(name: $0.name, colorHex: $0.colorHex, coins: $0.coins, isWinner: $0.isWinner, girl: $0.isGirl)
                              },
                              posterFile: posterFile, shotFiles: shotFiles, clipFile: clipFile)
            try JSONEncoder().encode(saved).write(to: folder.appending(path: "moment.json"), options: .completeFileProtection)
            return restore(from: saved)
        } catch {
            return nil
        }
    }

    // MARK: - Ler e apagar

    /// Do mais novo para o mais antigo.
    func list() -> [Moment] {
        let folders = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        let saved = folders.compactMap { folder -> Saved? in
            guard let data = try? Data(contentsOf: folder.appending(path: "moment.json")) else { return nil }
            return try? JSONDecoder().decode(Saved.self, from: data)
        }
        return saved.sorted { $0.date > $1.date }.map(restore(from:))
    }

    /// Junta o vídeo de avatares (já gerado em `tempURL`) ao momento salvo. Devolve o momento atualizado.
    @discardableResult
    func attachVideo(to id: UUID, from tempURL: URL) -> Moment? {
        let folder = root.appending(path: id.uuidString, directoryHint: .isDirectory)
        let target = folder.appending(path: "avatares.mp4")
        let jsonURL = folder.appending(path: "moment.json")
        guard let data = try? Data(contentsOf: jsonURL), var saved = try? JSONDecoder().decode(Saved.self, from: data) else { return nil }
        do {
            try? FileManager.default.removeItem(at: target)
            try FileManager.default.moveItem(at: tempURL, to: target)
            try (target as NSURL).setResourceValue(FileProtectionType.complete, forKey: .fileProtectionKey)
            saved.videoFile = "avatares.mp4"
            try JSONEncoder().encode(saved).write(to: folder.appending(path: "moment.json"), options: .completeFileProtection)
            return restore(from: saved)
        } catch {
            return nil
        }
    }

    func delete(_ id: UUID) {
        try? FileManager.default.removeItem(at: root.appending(path: id.uuidString, directoryHint: .isDirectory))
    }

    func deleteAll() {
        try? FileManager.default.removeItem(at: root)
    }

    private func restore(from saved: Saved) -> Moment {
        let folder = root.appending(path: saved.id.uuidString, directoryHint: .isDirectory)
        let relative = RelativeDateTimeFormatter()
        relative.unitsStyle = .full
        var moment = Moment(id: saved.id, title: saved.title, place: saved.place,
                            ago: Date().timeIntervalSince(saved.date) < 60 ? String(localized: "agora")
                                : relative.localizedString(for: saved.date, relativeTo: Date()),
                            durationSeconds: saved.durationSeconds, views: 0, likes: 0, mode: saved.mode, rounds: saved.rounds,
                            fastestMs: saved.fastestMs,
                            players: saved.players.map {
                                Moment.Player(name: $0.name, colorHex: $0.colorHex, coins: $0.coins, isWinner: $0.isWinner,
                                              isGirl: $0.girl ?? false)
                            })
        moment.isSample = false
        moment.posterURL = saved.posterFile.map { folder.appending(path: $0) }
        moment.shotURLs = saved.shotFiles.map { folder.appending(path: $0) }
        moment.videoURL = saved.videoFile.map { folder.appending(path: $0) }
        moment.realVideoURL = saved.clipFile.map { folder.appending(path: $0) }
        return moment
    }
}
