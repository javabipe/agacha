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
    private var audio: [String: Data] = [:]
    private var keepAlive: DispatchSourceTimer?
    private var onStreamsChanged: (@Sendable (Int) -> Void)?

    public init() {}

    /// Quantas TVs/navegadores estão conectados (para saber se vale mandar o som para lá).
    public var streamCount: Int {
        queue.sync { streams.count }
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
        let path = String(parts[1].split(separator: "?").first ?? "/")

        switch path {
        case "/", "/index.html":
            send(status: "200 OK", type: "text/html; charset=utf-8", body: Data(TVPage.html.utf8), on: connection)
        case "/events":
            openStream(on: connection)
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

    private func send(status: String, type: String, body: Data, on connection: NWConnection) {
        let head = "HTTP/1.1 \(status)\r\nContent-Type: \(type)\r\nContent-Length: \(body.count)\r\n"
            + "Cache-Control: no-store\r\nConnection: close\r\n\r\n"
        connection.send(content: Data(head.utf8) + body, completion: .contentProcessed { _ in connection.cancel() })
    }

    private func openStream(on connection: NWConnection) {
        let head = "HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\nCache-Control: no-store\r\n"
            + "Connection: keep-alive\r\nAccess-Control-Allow-Origin: *\r\n\r\nretry: 1000\n\n"
        let first = Data(head.utf8) + Data(Self.format(event: "state", data: (String(bytes: latestState, encoding: .utf8) ?? "")).utf8)
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
