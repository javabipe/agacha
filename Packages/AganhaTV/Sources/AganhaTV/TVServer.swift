// swiftlint:disable type_body_length
import Foundation
import Network
import os

/// Servidor HTTP mínimo na rede local: entrega a página da TV, o estado do jogo por Server-Sent Events e os sons.
/// Fica só no Wi-Fi da casa, sem internet, e nunca envia imagem da câmera.
public final class TVServer: @unchecked Sendable {
    public enum ServerError: Error {
        case couldNotStart
    }

    private let queue = DispatchQueue(label: "br.com.agacha.tv")
    private let logger = Logger(subsystem: "br.com.agacha.tv", category: "server")
    private var listener: NWListener?
    private var streams: [ObjectIdentifier: NWConnection] = [:]
    private var latestState = TVState(screen: "menu").json()
    private var latestPose = TVPose().json()
    private var audio: [String: Data] = [:]
    private var keepAlive: DispatchSourceTimer?
    private var onStreamsChanged: (@Sendable (Int) -> Void)?
    private var addedAudioOrder: [String] = []
    private var cameraToken: String?
    private var replayVideo: Data?
    private var cameraViewers: [ObjectIdentifier: CameraViewer] = [:]
    private static let maxAddedAudio = 40

    /// Uma TV vendo o vídeo da câmera. `busy` evita acumular quadros se a rede for mais lenta que a câmera.
    private final class CameraViewer {
        let connection: NWConnection
        var busy = false

        init(_ connection: NWConnection) {
            self.connection = connection
        }
    }

    public init() {}

    /// Quantas TVs/navegadores estão conectados (para saber se vale mandar o som para lá).
    public var streamCount: Int {
        queue.sync { streams.count }
    }

    /// Quantas TVs estão vendo o vídeo da câmera agora.
    public var cameraViewerCount: Int {
        queue.sync { cameraViewers.count }
    }

    /// Liga o vídeo da câmera (só abre com este código na URL) ou desliga (`nil`, e derruba quem estiver vendo).
    public func setCameraToken(_ token: String?) {
        queue.sync {
            cameraToken = token
            if token == nil {
                for viewer in cameraViewers.values { viewer.connection.cancel() }
                cameraViewers = [:]
            }
        }
    }

    /// Guarda (ou apaga, com `nil`) o vídeo do replay servido em `/replay.mp4`. Exige o mesmo código da câmera.
    public func setReplay(_ mp4: Data?) {
        queue.sync { replayVideo = mp4 }
    }

    /// Manda um quadro JPEG a quem está vendo a câmera (quem ainda está recebendo o anterior pula este).
    public func publishCameraFrame(_ jpeg: Data) {
        queue.async {
            let head = "--agachaframe\r\nContent-Type: image/jpeg\r\nContent-Length: \(jpeg.count)\r\n\r\n"
            let part = Data(head.utf8) + jpeg + Data("\r\n".utf8)
            for (key, viewer) in self.cameraViewers where !viewer.busy {
                viewer.busy = true
                viewer.connection.send(content: part, completion: .contentProcessed { [weak self] error in
                    self?.queue.async {
                        viewer.busy = false
                        if error != nil {
                            self?.cameraViewers.removeValue(forKey: key)
                            viewer.connection.cancel()
                        }
                    }
                })
            }
        }
    }

    /// Chamado (em fila de fundo) quando alguém conecta ou desconecta.
    public func setStreamsObserver(_ observer: (@Sendable (Int) -> Void)?) {
        queue.sync { onStreamsChanged = observer }
    }

    /// Começa a servir. `port` 0 escolhe uma livre. Devolve a porta usada.
    public func start(port: UInt16 = 8080, audio clips: [String: Data] = [:]) async throws -> UInt16 {
        stop()
        queue.sync { audio = clips }
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        let endpointPort = port == 0 ? NWEndpoint.Port.any : (NWEndpoint.Port(rawValue: port) ?? .any)
        let listener = try NWListener(using: parameters, on: endpointPort)
        listener.newConnectionHandler = { [weak self] connection in self?.accept(connection) }
        let box = StartBox()
        let usedPort: UInt16 = try await withCheckedThrowingContinuation { continuation in
            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if box.finish() { continuation.resume(returning: listener.port?.rawValue ?? port) }
                case let .failed(error):
                    if box.finish() { continuation.resume(throwing: error) }
                case .cancelled:
                    if box.finish() { continuation.resume(throwing: ServerError.couldNotStart) }
                default:
                    break
                }
            }
            listener.start(queue: queue)
        }
        queue.sync {
            self.listener = listener
            startKeepAlive()
        }
        return usedPort
    }

    public func stop() {
        queue.sync {
            keepAlive?.cancel()
            keepAlive = nil
            listener?.cancel()
            listener = nil
            for connection in streams.values { connection.cancel() }
            streams = [:]
            for viewer in cameraViewers.values { viewer.connection.cancel() }
            cameraViewers = [:]
        }
    }

    /// Guarda e envia o estado atual para todas as telas conectadas.
    public func publish(_ state: TVState) {
        let json = state.json()
        queue.async {
            self.latestState = json
            self.broadcast(event: "state", data: (String(bytes: json, encoding: .utf8) ?? ""))
        }
    }

    /// Posição dos jogadores (vai várias vezes por segundo, separada do estado).
    public func publishPose(_ pose: TVPose) {
        let json = pose.json()
        queue.async {
            self.latestPose = json
            self.broadcast(event: "pose", data: String(bytes: json, encoding: .utf8) ?? "{}")
        }
    }

    /// Acrescenta um som gerado agora (ex.: a voz do sistema falando um nome). Guarda só os últimos.
    public func addAudio(name: String, data: Data) {
        queue.async {
            if self.audio[name] == nil { self.addedAudioOrder.append(name) }
            self.audio[name] = data
            while self.addedAudioOrder.count > Self.maxAddedAudio {
                self.audio.removeValue(forKey: self.addedAudioOrder.removeFirst())
            }
        }
    }

    /// Manda a TV tocar o clipe `name` (arquivo em `/audio/<name>.wav`).
    public func playAudio(_ name: String) {
        queue.async { self.broadcast(event: "audio", data: name) }
    }

    /// Manda a TV falar um texto com a voz do navegador (se ele tiver).
    public func say(_ text: String) {
        queue.async { self.broadcast(event: "say", data: text.replacingOccurrences(of: "\n", with: " ")) }
    }

    public func stopAudio() {
        queue.async { self.broadcast(event: "stop", data: "1") }
    }

    // MARK: - Conexões

    private final class StartBox: @unchecked Sendable {
        private let lock = NSLock()
        private var done = false

        /// true na primeira chamada; as outras são ignoradas (a continuação só pode ser retomada uma vez).
        func finish() -> Bool {
            lock.withLock {
                guard !done else { return false }
                done = true
                return true
            }
        }
    }

    private func accept(_ connection: NWConnection) {
        connection.start(queue: queue)
        receive(on: connection, buffer: Data())
    }

    private func receive(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            var buffer = buffer
            if let data { buffer.append(data) }
            if let end = buffer.range(of: Data("\r\n\r\n".utf8)) {
                let head = (String(bytes: buffer[..<end.lowerBound], encoding: .utf8) ?? "")
                respond(to: head, on: connection)
            } else if isComplete || error != nil || buffer.count > 16_384 {
                connection.cancel()
            } else {
                receive(on: connection, buffer: buffer)
            }
        }
    }

    private func respond(to head: String, on connection: NWConnection) {
        let requestLine = head.split(separator: "\r\n", maxSplits: 1).first.map(String.init) ?? ""
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2, parts[0] == "GET" else {
            send(status: "405 Method Not Allowed", type: "text/plain", body: Data("só GET".utf8), on: connection)
            return
        }
        let target = String(parts[1])
        let path = String(target.split(separator: "?").first ?? "/")
        let query = target.contains("?") ? String(target.split(separator: "?", maxSplits: 1).last ?? "") : ""

        switch path {
        case "/", "/index.html":
            send(status: "200 OK", type: "text/html; charset=utf-8", body: Data(TVPage.html.utf8), on: connection)
        case "/events":
            openStream(on: connection)
        case "/camera.mjpg":
            openCamera(on: connection, query: query)
        case "/replay.mp4":
            serveReplay(head: head, query: query, on: connection)
        case "/state":
            send(status: "200 OK", type: "application/json", body: latestState, on: connection)
        case "/clips":
            let names = audio.keys.sorted()
            let body = (try? JSONEncoder().encode(names)) ?? Data("[]".utf8)
            send(status: "200 OK", type: "application/json", body: body, on: connection)
        case let path where path.hasPrefix("/audio/") && path.hasSuffix(".wav"):
            let name = String(path.dropFirst("/audio/".count).dropLast(".wav".count))
            if let data = audio[name] {
                send(status: "200 OK", type: "audio/wav", body: data, on: connection)
            } else {
                send(status: "404 Not Found", type: "text/plain", body: Data("sem esse som".utf8), on: connection)
            }
        case "/favicon.ico":
            send(status: "204 No Content", type: "image/x-icon", body: Data(), on: connection)
        default:
            send(status: "404 Not Found", type: "text/plain", body: Data("não encontrado".utf8), on: connection)
        }
    }

    private func send(status: String, type: String, body: Data, on connection: NWConnection, extra: String = "") {
        let head = "HTTP/1.1 \(status)\r\nContent-Type: \(type)\r\nContent-Length: \(body.count)\r\n" + extra
            + "Cache-Control: no-store\r\nConnection: close\r\n\r\n"
        connection.send(content: Data(head.utf8) + body, completion: .contentProcessed { _ in connection.cancel() })
    }

    private func openStream(on connection: NWConnection) {
        let head = "HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\nCache-Control: no-store\r\n"
            + "Connection: keep-alive\r\nAccess-Control-Allow-Origin: *\r\n\r\nretry: 1000\n\n"
        let first = Data(head.utf8)
            + Data(Self.format(event: "state", data: String(bytes: latestState, encoding: .utf8) ?? "").utf8)
            + Data(Self.format(event: "pose", data: String(bytes: latestPose, encoding: .utf8) ?? "").utf8)
        let key = ObjectIdentifier(connection)
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed, .cancelled:
                self?.queue.async { self?.removeStream(key) }
            default:
                break
            }
        }
        connection.send(content: first, completion: .contentProcessed { [weak self] error in
            guard let self else { return }
            if error != nil {
                connection.cancel()
                return
            }
            queue.async {
                self.streams[key] = connection
                self.notifyStreams()
            }
        })
    }

    /// Vídeo do replay: só com o código certo, com suporte a `Range` (os navegadores de TV pedem o vídeo em pedaços).
    private func serveReplay(head: String, query: String, on connection: NWConnection) {
        let code = query.split(separator: "&").first { $0.hasPrefix("t=") }.map { String($0.dropFirst(2)) }
        guard let token = cameraToken, code == token else {
            send(status: "403 Forbidden", type: "text/plain", body: Data("código inválido".utf8), on: connection)
            return
        }
        guard let video = replayVideo else {
            send(status: "404 Not Found", type: "text/plain", body: Data("sem replay".utf8), on: connection)
            return
        }
        let total = video.count
        guard let (start, end) = Self.byteRange(in: head, total: total) else {
            send(status: "200 OK", type: "video/mp4", body: video, on: connection, extra: "Accept-Ranges: bytes\r\n")
            return
        }
        guard start <= end, end < total else {
            send(status: "416 Range Not Satisfiable", type: "text/plain", body: Data(), on: connection,
                 extra: "Content-Range: bytes */\(total)\r\n")
            return
        }
        send(status: "206 Partial Content", type: "video/mp4", body: video.subdata(in: start..<(end + 1)), on: connection,
             extra: "Accept-Ranges: bytes\r\nContent-Range: bytes \(start)-\(end)/\(total)\r\n")
    }

    /// Lê `Range: bytes=a-b`, `a-` ou `-n` dos cabeçalhos. nil se não houver.
    static func byteRange(in head: String, total: Int) -> (Int, Int)? {
        guard let line = head.split(separator: "\r\n").first(where: { $0.lowercased().hasPrefix("range:") }),
              let spec = line.split(separator: "=", maxSplits: 1).last else { return nil }
        let bounds = spec.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
            .map { Int($0.trimmingCharacters(in: .whitespaces)) }
        guard bounds.count == 2 else { return nil }
        switch (bounds[0], bounds[1]) {
        case let (start?, end?): return (start, min(end, total - 1))
        case let (start?, nil): return (start, total - 1)
        case let (nil, suffix?): return (max(0, total - suffix), total - 1)
        default: return nil
        }
    }

    /// Vídeo da câmera (MJPEG): só com o código certo e com a câmera ligada no app.
    private func openCamera(on connection: NWConnection, query: String) {
        let code = query.split(separator: "&").first { $0.hasPrefix("t=") }.map { String($0.dropFirst(2)) }
        guard let token = cameraToken, code == token else {
            send(status: "403 Forbidden", type: "text/plain", body: Data("código inválido".utf8), on: connection)
            return
        }
        let head = "HTTP/1.1 200 OK\r\nContent-Type: multipart/x-mixed-replace; boundary=agachaframe\r\n"
            + "Cache-Control: no-store\r\nConnection: close\r\n\r\n"
        let key = ObjectIdentifier(connection)
        let viewer = CameraViewer(connection)
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed, .cancelled:
                self?.queue.async { self?.cameraViewers.removeValue(forKey: key) }
            default:
                break
            }
        }
        connection.send(content: Data(head.utf8), completion: .contentProcessed { [weak self] error in
            guard let self else { return }
            if error != nil {
                connection.cancel()
                return
            }
            queue.async { self.cameraViewers[key] = viewer }
        })
    }

    private func removeStream(_ key: ObjectIdentifier) {
        if streams.removeValue(forKey: key) != nil { notifyStreams() }
    }

    private func notifyStreams() {
        onStreamsChanged?(streams.count)
    }

    private func broadcast(event: String, data: String) {
        let message = Data(Self.format(event: event, data: data).utf8)
        for (key, connection) in streams {
            connection.send(content: message, completion: .contentProcessed { [weak self] error in
                if error != nil { self?.queue.async { self?.removeStream(key); connection.cancel() } }
            })
        }
    }

    private func startKeepAlive() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 10, repeating: 10)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            let ping = Data(": ping\n\n".utf8)
            for (key, connection) in streams {
                connection.send(content: ping, completion: .contentProcessed { [weak self] error in
                    if error != nil { self?.queue.async { self?.removeStream(key); connection.cancel() } }
                })
            }
        }
        timer.resume()
        keepAlive = timer
    }

    static func format(event: String, data: String) -> String {
        "event: \(event)\ndata: \(data)\n\n"
    }
}
// swiftlint:enable type_body_length
