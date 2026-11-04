import AganhaAudio
import AganhaTV
import Foundation
import Observation
import os

/// Liga o jogo à TV: sobe/derruba o servidor da rede local e manda o estado e os sons para o navegador da TV.
@MainActor
@Observable
final class TVBridge {
    private(set) var isOn = false
    private(set) var isStarting = false
    /// Endereço para digitar no navegador da TV.
    private(set) var address: String?
    /// Endereço do iPad na rede da casa (para o agacha.app levar a TV até aqui).
    private(set) var host: String?
    private(set) var port: Int?
    private(set) var cameraToken: String?
    /// Quantos navegadores estão conectados agora.
    private(set) var connectedScreens = 0
    private(set) var errorMessage: String?
    /// Mostrar a câmera de verdade na tela de posicionamento (teste). Exige o código na URL.
    private(set) var cameraOn = false
    private(set) var cameraAddress: String?
    /// O replay (quadros JPEG) está pronto para a TV baixar; a versão muda a cada replay.
    private(set) var replay: TVState.Replay?
    private var replayVersion = 0
    /// Tocar os sons na TV (em vez do iPad) quando houver TV conectada.
    var soundOnTV = true

    @ObservationIgnored let server = TVServer()
    @ObservationIgnored private(set) lazy var cameraStreamer = CameraStreamer(server: server)
    @ObservationIgnored private let logger = Logger(subsystem: "br.com.agacha.app", category: "tv")

    /// Saída de som para o `AudioPlayer`: só vale com a TV ligada, conectada e com o som da TV ativo.
    var audioOutput: RemoteOutput {
        RemoteOutput(isActive: { [self] in isOn && soundOnTV && connectedScreens > 0 },
                     play: { [self] name in server.playAudio(name) },
                     stop: { [self] in server.stopAudio() },
                     playData: { [self] name, data in
                         server.addAudio(name: name, data: data)
                         server.playAudio(name)
                     })
    }

    func setEnabled(_ on: Bool) async {
        guard on != isOn, !isStarting else { return }
        guard on else {
            server.stop()
            replay = nil
            cameraStreamer.setEnabled(false)
            isOn = false
            address = nil
            host = nil
            port = nil
            cameraToken = nil
            cameraOn = false
            cameraAddress = nil
            connectedScreens = 0
            return
        }
        isStarting = true
        defer { isStarting = false }
        errorMessage = nil
        let clips = await Task.detached { AudioPlayer.wavClips() }.value
        do {
            let port = try await startServer(clips: clips)
            server.setStreamsObserver { [weak self] count in
                Task { @MainActor in self?.connectedScreens = count }
            }
            host = LocalAddress.ipv4()
            self.port = Int(port)
            address = "http://\(host ?? "?"):\(port)"
            isOn = true
        } catch {
            logger.error("Servidor da TV não iniciou: \(error.localizedDescription, privacy: .public)")
            errorMessage = String(localized: "Não consegui ligar a TV. Confira se o iPad está no Wi-Fi.")
        }
    }

    /// Entrega (ou apaga, com lista vazia) os quadros do replay à TV. Só serve a quem tem o código da câmera.
    func setReplay(_ frames: [Data], framesPerSecond: Int = 10) {
        server.setReplayFrames(frames)
        guard !frames.isEmpty else {
            replay = nil
            return
        }
        replayVersion += 1
        replay = TVState.Replay(frames: frames.count, version: replayVersion, fps: framesPerSecond)
    }

    func publishPose(_ pose: TVPose) {
        guard isOn else { return }
        server.publishPose(pose)
    }

    func publish(_ state: TVState) {
        guard isOn else { return }
        server.publish(state)
    }

    /// Liga/desliga o vídeo da câmera na TV. Quem abrir o endereço sem o código não vê a câmera.
    func setCamera(_ on: Bool) {
        guard isOn else { return }
        guard on else {
            server.setCameraToken(nil)
            cameraStreamer.setEnabled(false)
            cameraOn = false
            cameraAddress = nil
            cameraToken = nil
            return
        }
        let token = String(Int.random(in: 1000...9999))
        server.setCameraToken(token)
        cameraOn = true
        cameraToken = token
        cameraAddress = address.map { "\($0)/?t=\(token)" }
    }

    func say(_ text: String) {
        guard isOn, soundOnTV, connectedScreens > 0 else { return }
        server.say(text)
    }

    /// Porta 8080 (fácil de digitar); se estiver ocupada, uma livre.
    private func startServer(clips: [String: Data]) async throws -> UInt16 {
        do {
            return try await server.start(port: 8080, audio: clips)
        } catch {
            return try await server.start(port: 0, audio: clips)
        }
    }
}
