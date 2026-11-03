import AganhaVision
import CoreVideo
import Foundation

/// Guarda, na memória, uma foto recente da câmera (a cada ~0,8 s, só enquanto "armado" durante a partida) para o jogo poder
/// salvar "shots" dos melhores momentos. Chamado só na fila da câmera; nada vai para a rede.
final class ShotCapturer: @unchecked Sendable {
    static let minInterval = 0.8

    private let encoder = FrameJPEG()
    private let lock = NSLock()
    private var armed = false
    private var lastTime = 0.0
    private var latest: Data?

    func setArmed(_ on: Bool) {
        lock.withLock {
            armed = on
            if !on { latest = nil }
        }
    }

    func offer(_ buffer: CVPixelBuffer, at time: Double) {
        let due = lock.withLock { () -> Bool in
            guard armed, time - lastTime >= Self.minInterval else { return false }
            lastTime = time
            return true
        }
        guard due, let jpeg = encoder.encode(buffer, maxWidth: 720, quality: 0.7) else { return }
        lock.withLock { latest = jpeg }
    }

    /// A foto mais recente (ou nil se não está armado).
    func snapshot() -> Data? { lock.withLock { latest } }
}
