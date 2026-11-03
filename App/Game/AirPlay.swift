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

/// Como ver o jogo na TV. O espelhamento da tela inteira é do sistema (Centro de Controle); um app não consegue ligá-lo.
struct TVHelpView: View {
    let monitor: MirroringMonitor
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label(monitor.isMirroring ? "A tela do iPad está aparecendo na TV." : "A tela ainda não está na TV.",
                          systemImage: monitor.isMirroring ? "checkmark.tv.fill" : "tv")
                        .font(.headline)
                        .foregroundStyle(monitor.isMirroring ? Color.green : Color.primary)
                }
                Section("Espelhar a tela do iPad (recomendado)") {
                    Text("1. Ligue a TV e confirme que o AirPlay está ativo nela "
                         + "(em muitas Samsung: Configurações › Geral › Configurações do Apple AirPlay).")
                    Text("2. No iPad, deslize para baixo a partir do canto superior direito para abrir o Centro de Controle.")
                    Text("3. Toque em Espelhamento de Tela (dois retângulos) e escolha a sua TV. "
                         + "Se a TV mostrar um código, digite no iPad.")
                    Text("4. Volte ao Agacha: a TV mostra a mesma tela e o som sai por ela.")
                }
                Section {
                    HStack {
                        Text("Seletor de AirPlay do app")
                        Spacer()
                        AirPlayButton().frame(width: 36, height: 36)
                    }
                } footer: {
                    Text("Este botão funciona como o do YouTube e, para um app de jogo, costuma mandar só o som para a TV "
                         + "(em algumas TVs, nem isso). Para ver a imagem, use o Espelhamento de Tela acima.")
                }
                Section {
                    Text("Apps como AirBeamTV espelham o iPad em TVs Samsung pela rede Wi-Fi. "
                         + "Inicie o espelhamento nele e depois abra o Agacha.")
                    Text("Eles têm atraso de cerca de 1 a 3 segundos. Ajuste \"Atraso da TV\" no menu (comece com 2 s): "
                         + "os prazos de reação passam a contar depois desse atraso.")
                    Text("O som sai no iPad e na TV (atrasado): deixe o volume do iPad no mínimo e use o som da TV.")
                } header: {
                    Text("Se a TV não aceita AirPlay")
                } footer: {
                    Text("Teste antes de contar com isso: o atraso pode atrapalhar a brincadeira, "
                         + "e nem todo app deixa a câmera funcionar ao mesmo tempo.")
                }
                Section("Sem AirPlay?") {
                    Text("Um cabo ou adaptador USB-C para HDMI espelha o iPad na TV sem depender de rede.")
                }
            }
            .navigationTitle("Ver na TV")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Fechar") { dismiss() } }
        }
    }
}
