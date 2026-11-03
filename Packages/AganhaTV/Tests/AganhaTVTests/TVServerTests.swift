@testable import AganhaTV
import Foundation
import Testing

private final class Collected: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String] = []
    var lines: [String] { lock.withLock { storage } }
    func add(_ line: String) { lock.withLock { storage.append(line) } }
}

@Suite(.serialized) struct TVServerTests {
    private func start(audio: [String: Data] = [:]) async throws -> (TVServer, UInt16) {
        let server = TVServer()
        let port = try await server.start(port: 0, audio: audio)
        return (server, port)
    }

    private func get(_ port: UInt16, _ path: String) async throws -> (Int, Data) {
        let url = URL(string: "http://127.0.0.1:\(port)\(path)")!
        let (data, response) = try await URLSession.shared.data(from: url)
        return ((response as? HTTPURLResponse)?.statusCode ?? 0, data)
    }

    @Test func servesThePageAndKnowsWhenSomethingIsMissing() async throws {
        let (server, port) = try await start()
        defer { server.stop() }
        let (status, body) = try await get(port, "/")
        #expect(status == 200)
        #expect((String(bytes: body, encoding: .utf8) ?? "").contains("EventSource"))
        #expect(try await get(port, "/nada").0 == 404)
        #expect(try await get(port, "/audio/nao_existe.wav").0 == 404)
    }

    @Test func servesAudioAndTheClipList() async throws {
        let wav = Data([1, 2, 3, 4, 5])
        let (server, port) = try await start(audio: ["lu_cmd_vivo_v1": wav, "lu_cmd_morto_v1": wav])
        defer { server.stop() }
        let (status, body) = try await get(port, "/audio/lu_cmd_vivo_v1.wav")
        #expect(status == 200)
        #expect(body == wav)
        let names = try JSONDecoder().decode([String].self, from: try await get(port, "/clips").1)
        #expect(names == ["lu_cmd_morto_v1", "lu_cmd_vivo_v1"])
    }

    @Test func publishedStateIsServedAndStreamed() async throws {
        let (server, port) = try await start()
        defer { server.stop() }
        server.publish(TVState(screen: "play", word: "VIVO!", background: "#1FA98A", gesture: "down", trick: true,
                               players: [.init(name: "Paulo", color: "#FFC845")]))
        try await Task.sleep(for: .milliseconds(100))
        let state = try JSONDecoder().decode(TVState.self, from: try await get(port, "/state").1)
        #expect(state.word == "VIVO!")
        #expect(state.trick)
        #expect(state.players.first?.name == "Paulo")

        // Quem conecta no fluxo já recebe o estado atual, e depois as novidades.
        let url = URL(string: "http://127.0.0.1:\(port)/events")!
        let (bytes, _) = try await URLSession.shared.bytes(from: url)
        let collected = Collected()
        let reader = Task {
            for try await line in bytes.lines {
                collected.add(line)
                if collected.lines.contains("data: lu_cmd_vivo_v1") { break }
            }
        }
        try await Task.sleep(for: .milliseconds(300))
        #expect(server.streamCount == 1)
        server.playAudio("lu_cmd_vivo_v1")
        _ = try await reader.value
        let lines = collected.lines
        #expect(lines.contains("event: state"))
        #expect(lines.contains { $0.hasPrefix("data: {") && $0.contains("VIVO!") })
        #expect(lines.contains("data: lu_cmd_vivo_v1"))
    }

    @Test func stopClosesStreamsAndRefusesNewOnes() async throws {
        let (server, port) = try await start()
        server.stop()
        try await Task.sleep(for: .milliseconds(100))
        await #expect(throws: (any Error).self) { _ = try await self.get(port, "/") }
        #expect(server.streamCount == 0)
    }

    @Test func stateRoundTripsThroughJSON() throws {
        let player = TVState.Player(name: "A", color: "#000000", out: true, detail: "✕")
        let state = TVState(screen: "result", message: "Paulo errou!", players: [player])
        #expect(try JSONDecoder().decode(TVState.self, from: state.json()) == state)
    }

    @Test func localAddressLooksLikeIPv4WhenThereIsANetwork() {
        if let address = LocalAddress.ipv4() {
            #expect(address.split(separator: ".").count == 4)
        }
    }
}
