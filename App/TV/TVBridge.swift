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
    /// Quantos navegadores estão conectados agora.
    private(set) var connectedScreens = 0
    private(set) var errorMessage: String?
    /// Tocar os sons na TV (em vez do iPad) quando houver TV conectada.
    var soundOnTV = true

    @ObservationIgnored private let server = TVServer()
    @ObservationIgnored private let logger = Logger(subsystem: "br.com.agacha.app", category: "tv")

    /// Saída de som para o `AudioPlayer`: só vale com a TV ligada, conectada e com o som da TV ativo.
    var audioOutput: RemoteOutput {
        RemoteOutput(isActive: { [self] in isOn && soundOnTV && connectedScreens > 0 },
                     play: { [self] name in server.playAudio(name) },
                     stop: { [self] in server.stopAudio() })
    }

    func setEnabled(_ on: Bool) async {
        guard on != isOn, !isStarting else { return }
        guard on else {
            server.stop()
            isOn = false
            address = nil
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
            address = "http://\(LocalAddress.ipv4() ?? "?"):\(port)"
            isOn = true
        } catch {
            logger.error("Servidor da TV não iniciou: \(error.localizedDescription, privacy: .public)")
            errorMessage = String(localized: "Não consegui ligar a TV. Confira se o iPad está no Wi-Fi.")
        }
    }

    func publish(_ state: TVState) {
        guard isOn else { return }
        server.publish(state)
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
