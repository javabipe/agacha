@testable import AganhaTV
import Foundation
import Network
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

    // MARK: - Câmera e posição

    @Test func cameraNeedsTheRightCodeAndIsOffByDefault() async throws {
        let (server, port) = try await start()
        defer { server.stop() }
        #expect(try await get(port, "/camera.mjpg").0 == 403)
        #expect(try await get(port, "/camera.mjpg?t=1234").0 == 403)   // câmera desligada
        server.setCameraToken("4321")
        #expect(try await get(port, "/camera.mjpg?t=1234").0 == 403)   // código errado
        #expect(try await get(port, "/camera.mjpg").0 == 403)
    }

    @Test func cameraFramesReachAViewerWithTheCodeAndStopWhenDisabled() async throws {
        let (server, port) = try await start()
        defer { server.stop() }
        server.setCameraToken("4321")
        let jpeg = Data([0xFF, 0xD8] + Array(repeating: 7, count: 150) + [0xFF, 0xD9])
        // Como uma TV: abre a conexão, lê o cabeçalho e depois os quadros.
        let client = RawClient(port: port)
        try await client.connect()
        client.send("GET /camera.mjpg?t=4321 HTTP/1.1\r\nHost: tv\r\n\r\n")
        try await Task.sleep(for: .milliseconds(300))
        #expect(server.cameraViewerCount == 1)
        server.publishCameraFrame(jpeg)
        let received = try await client.read(until: jpeg, timeout: 3)
        let frameStart = try #require(received.range(of: jpeg)).lowerBound
        let text = String(bytes: received[..<frameStart], encoding: .utf8) ?? ""
        #expect(text.hasPrefix("HTTP/1.1 200 OK"))
        #expect(text.contains("multipart/x-mixed-replace; boundary=agachaframe"))
        #expect(text.contains("--agachaframe\r\nContent-Type: image/jpeg\r\nContent-Length: \(jpeg.count)\r\n\r\n"))
        #expect(received.range(of: jpeg) != nil)

        server.setCameraToken(nil)
        try await Task.sleep(for: .milliseconds(200))
        #expect(server.cameraViewerCount == 0)
        client.close()
    }

    @Test func poseGoesOnItsOwnChannelAndNewViewersGetTheLastOne() async throws {
        let (server, port) = try await start()
        defer { server.stop() }
        let joints = ["n": [0.5, 0.2], "ls": [0.45, 0.3]]
        server.publishPose(TVPose(aspect: 1.7778, figures: [.init(name: "Paulo", color: "#FFC845", ready: true, joints: joints)]))
        try await Task.sleep(for: .milliseconds(100))
        let url = URL(string: "http://127.0.0.1:\(port)/events")!
        let (bytes, _) = try await URLSession.shared.bytes(from: url)
        let collected = Collected()
        let reader = Task {
            for try await line in bytes.lines {
                collected.add(line)
                if collected.lines.contains(where: { $0.hasPrefix("data: {") && $0.contains("\"figures\"") }) { break }
            }
        }
        _ = try await reader.value
        let lines = collected.lines
        #expect(lines.contains("event: pose"))
        let data = try #require(lines.first { $0.hasPrefix("data: {") && $0.contains("\"figures\"") })
        let pose = try JSONDecoder().decode(TVPose.self, from: Data(data.dropFirst(6).utf8))
        #expect(pose.figures.first?.joints["n"] == [0.5, 0.2])
    }
}

extension TVServerTests {
    @Test func eventsReachTheTVQuicklyEvenWhenSentOftenAndSmall() async throws {
        let (server, port) = try await start()
        defer { server.stop() }
        let client = RawClient(port: port)
        try await client.connect()
        client.send("GET /events HTTP/1.1\r\nHost: tv\r\n\r\n")
        try await Task.sleep(for: .milliseconds(300))
        // 100 posições pequenas em sequência, como a câmera a 30 por segundo: a última não pode ficar presa na fila.
        for index in 0..<100 {
            let figure = TVState.Figure(name: "P\(index)", color: "#fff", ready: true, joints: ["n": [0.5, 0.2]])
            server.publishPose(TVPose(aspect: 1.7778, figures: [figure]))
            try await Task.sleep(for: .milliseconds(5))
        }
        let started = Date()
        let data = try await client.read(until: Data("\"name\":\"P99\"".utf8), timeout: 2)
        #expect(data.range(of: Data("\"name\":\"P99\"".utf8)) != nil)
        #expect(Date().timeIntervalSince(started) < 0.5)
        client.close()
    }

    @Test func replayNeedsTheCodeAndSupportsRanges() async throws {
        let (server, port) = try await start()
        defer { server.stop() }
        let video = Data((0..<1000).map { UInt8($0 % 251) })
        server.setReplay(video)
        // Sem câmera/código ligados: negado, mesmo com vídeo guardado.
        #expect(try await get(port, "/replay.mp4?t=1111").0 == 403)
        server.setCameraToken("1111")
        #expect(try await get(port, "/replay.mp4?t=9999").0 == 403)
        let whole = try await get(port, "/replay.mp4?v=1&t=1111")
        #expect(whole.0 == 200)
        #expect(whole.1 == video)

        func partial(_ range: String) async throws -> (Int, Data, String?) {
            var request = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/replay.mp4?t=1111")!)
            request.setValue(range, forHTTPHeaderField: "Range")
            let (data, response) = try await URLSession.shared.data(for: request)
            let http = response as? HTTPURLResponse
            return (http?.statusCode ?? 0, data, http?.value(forHTTPHeaderField: "Content-Range"))
        }
        let first = try await partial("bytes=0-99")
        #expect(first.0 == 206 && first.1 == video.prefix(100) && first.2 == "bytes 0-99/1000")
        let open = try await partial("bytes=900-")
        #expect(open.0 == 206 && open.1 == video.suffix(100) && open.2 == "bytes 900-999/1000")
        let tail = try await partial("bytes=-50")
        #expect(tail.0 == 206 && tail.1 == video.suffix(50))
        #expect(try await partial("bytes=2000-3000").0 == 416)

        server.setReplay(nil)
        #expect(try await get(port, "/replay.mp4?t=1111").0 == 404)
    }

    @Test func byteRangeParsing() {
        #expect(TVServer.byteRange(in: "GET / HTTP/1.1\r\nRange: bytes=5-9", total: 100)! == (5, 9))
        #expect(TVServer.byteRange(in: "GET / HTTP/1.1\r\nrange: bytes=90-", total: 100)! == (90, 99))
        #expect(TVServer.byteRange(in: "GET / HTTP/1.1\r\nRange: bytes=-10", total: 100)! == (90, 99))
        #expect(TVServer.byteRange(in: "GET / HTTP/1.1\r\nHost: x", total: 100) == nil)
    }
}

/// Cliente TCP simples (como o navegador da TV), para ver exatamente o que o servidor envia.
private final class RawClient: @unchecked Sendable {
    private let connection: NWConnection
    private let lock = NSLock()
    private var buffer = Data()

    init(port: UInt16) {
        connection = NWConnection(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: port)!, using: .tcp)
    }

    func connect() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let once = Once()
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready: if once.first() { continuation.resume() }
                case let .failed(error): if once.first() { continuation.resume(throwing: error) }
                default: break
                }
            }
            connection.start(queue: .global())
        }
        receiveLoop()
    }

    func send(_ text: String) {
        connection.send(content: Data(text.utf8), completion: .contentProcessed { _ in })
    }

    func read(until marker: Data, timeout: Double) async throws -> Data {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            let current = lock.withLock { buffer }
            if current.range(of: marker) != nil { return current }
            try await Task.sleep(for: .milliseconds(25))
        }
        return lock.withLock { buffer }
    }

    func close() { connection.cancel() }

    private func receiveLoop() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data { lock.withLock { buffer.append(data) } }
            if !isComplete, error == nil { receiveLoop() }
        }
    }

    private final class Once: @unchecked Sendable {
        private let lock = NSLock()
        private var done = false
        func first() -> Bool { lock.withLock { defer { done = true }; return !done } }
    }
}
