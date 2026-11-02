import AVKit
import Observation
import SwiftUI
import UIKit

/// Botão de AirPlay do sistema: lista as TVs e telas por perto. Escolhendo uma TV com AirPlay, o iPad espelha a tela nela.
struct AirPlayButton: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.prioritizesVideoDevices = true
        picker.tintColor = UIColor.white.withAlphaComponent(0.85)
        picker.activeTintColor = UIColor(red: 0.21, green: 0.79, blue: 0.65, alpha: 1)
        picker.accessibilityLabel = String(localized: "Enviar a tela para a TV (AirPlay)")
        return picker
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}

/// Avisa quando a tela está sendo espelhada ou gravada (por exemplo, numa TV por AirPlay).
@MainActor
@Observable
final class MirroringMonitor {
    private(set) var isMirroring = false
    @ObservationIgnored private nonisolated(unsafe) var observer: NSObjectProtocol?

    init() {
        refresh()
        observer = NotificationCenter.default.addObserver(forName: UIScreen.capturedDidChangeNotification, object: nil,
                                                          queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    private func refresh() {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        isMirroring = scenes.contains { $0.screen.isCaptured }
    }
}
