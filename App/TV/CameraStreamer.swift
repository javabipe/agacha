import AganhaTV
import AganhaVision
import CoreVideo
import Foundation

/// Manda a câmera para a TV como vídeo MJPEG, só quando ligado e com alguém assistindo.
/// Chamado na fila da câmera a cada quadro; reduz para ~8 quadros por segundo e 640 px de largura.
final class CameraStreamer: @unchecked Sendable {
    static let minInterval = 0.125

    private let server: TVServer
    private let encoder = FrameJPEG()
    private let lock = NSLock()
    private var enabled = false
    private var lastSent = 0.0

    init(server: TVServer) {
        self.server = server
    }

    func setEnabled(_ value: Bool) {
        lock.withLock { enabled = value }
    }

    func offer(_ buffer: CVPixelBuffer, at time: Double) {
        let due = lock.withLock { () -> Bool in
            guard enabled, time - lastSent >= Self.minInterval else { return false }
            lastSent = time
            return true
        }
        guard due, server.cameraViewerCount > 0, let jpeg = encoder.encode(buffer) else { return }
        server.publishCameraFrame(jpeg)
    }
}
