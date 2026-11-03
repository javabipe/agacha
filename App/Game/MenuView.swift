import AganhaCore
import SwiftUI

struct MenuView: View {
    @Bindable var loop: GameLoop
    let onPlay: () -> Void
    let onDiagnostic: () -> Void
    @State private var mirroring = MirroringMonitor()
    @State private var showTV = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 28) {
                    VStack(spacing: 4) {
                        Text("Aganha!")
                            .font(.system(size: 72, weight: .black, design: .rounded))
                            .foregroundStyle(Color.aganhaYellow)
                        Text("A brincadeira do morto-vivo")
                            .font(.title3)
                            .foregroundStyle(Color.aganhaCream)
                    }
                    .padding(.top, 40)

                    VStack(alignment: .leading, spacing: 20) {
                        picker("Nível", selection: $loop.settings.difficulty, options: Difficulty.allCases, label: Self.name)
                        picker("Tempo para reagir", selection: $loop.settings.tolerance, options: Tolerance.allCases, label: Self.name)
                        picker("Comandos", selection: $loop.settings.commandSet, options: [.classic, .school], label: Self.name)
                        picker("Erros permitidos por jogador", selection: $loop.settings.maxErrors, options: [1, 2, 3, 5]) {
                            $0 == 1 ? String(localized: "1 (sai no primeiro)") : "\($0)"
                        }
                        Toggle("Perguntar o nome de cada jogador", isOn: $loop.settings.askNames)
                            .font(.headline)
                            .foregroundStyle(Color.aganhaCream)
                        Stepper(value: $loop.settings.tvDelay, in: 0...5, step: 0.5) {
                            Text("Atraso da TV: \(loop.settings.tvDelay.formatted(.number.precision(.fractionLength(1)))) s")
                                .font(.headline)
                                .foregroundStyle(Color.aganhaCream)
                        }
                        Toggle("Replay em vídeo do erro (apagado em seguida)", isOn: $loop.settings.recordReplay)
                            .font(.headline)
                            .foregroundStyle(Color.aganhaCream)
                    }
                    .padding(20)
                    .background(.black.opacity(0.3), in: .rect(cornerRadius: 20))

                    Button(action: onPlay) {
                        Text("Jogar")
                            .font(.system(size: 34, weight: .heavy, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(hex: "#36C9A6"))

                    tvControls

                    Button(mirroring.isMirroring ? "Ver na TV (conectada)" : "Ver na TV", systemImage: "tv") { showTV = true }
                        .foregroundStyle(Color.aganhaCream.opacity(mirroring.isMirroring ? 1 : 0.9))

                    Button("Diagnóstico da câmera", action: onDiagnostic)
                        .foregroundStyle(Color.aganhaCream.opacity(0.7))
                }
                .frame(maxWidth: 560)
                .padding(24)
                .frame(maxWidth: .infinity)
            }
        }
        .sheet(isPresented: $showTV) { TVHelpView(monitor: mirroring, tv: loop.tv) }
    }

    /// Mostrar o jogo no navegador da TV (rede Wi-Fi), com ou sem o som.
    private var tvControls: some View {
        VStack(spacing: 8) {
            Toggle("Mostrar na TV pelo navegador", isOn: Binding(get: { loop.tv.isOn }, set: { loop.setTVEnabled($0) }))
                .font(.headline)
                .foregroundStyle(Color.aganhaCream)
            if loop.tv.isOn, let address = loop.tv.address {
                Text("Na TV, abra o navegador e digite:")
                    .font(.callout)
                    .foregroundStyle(Color.aganhaCream.opacity(0.85))
                Text(address)
                    .font(.system(size: 30, weight: .heavy, design: .monospaced))
                    .foregroundStyle(Color.aganhaYellow)
                    .textSelection(.enabled)
                Text(loop.tv.connectedScreens == 0 ? "Nenhuma TV conectada ainda"
                     : "\(loop.tv.connectedScreens) tela(s) conectada(s)")
                    .font(.callout)
                    .foregroundStyle(loop.tv.connectedScreens == 0 ? Color.aganhaCream.opacity(0.7) : Color.green)
                Toggle("Som na TV", isOn: Binding(get: { loop.tv.soundOnTV }, set: { loop.tv.soundOnTV = $0 }))
                    .font(.headline)
                    .foregroundStyle(Color.aganhaCream)
            }
            if let error = loop.tv.errorMessage {
                Text(error).font(.callout).foregroundStyle(.orange)
            }
        }
        .padding(16)
        .background(.black.opacity(0.3), in: .rect(cornerRadius: 20))
    }

    private func picker<Value: Hashable>(_ title: LocalizedStringKey, selection: Binding<Value>, options: [Value],
                                         label: @escaping (Value) -> String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline).foregroundStyle(Color.aganhaCream)
            Picker(title, selection: selection) {
                ForEach(options, id: \.self) { Text(label($0)).tag($0) }
            }
            .pickerStyle(.segmented)
        }
    }

    private static func name(_ difficulty: Difficulty) -> String {
        switch difficulty {
        case .tranquilo: String(localized: "Tranquilo")
        case .sapeca: String(localized: "Sapeca")
        case .furacao: String(localized: "Furacão")
        }
    }

    private static func name(_ tolerance: Tolerance) -> String {
        switch tolerance {
        case .pequenos: String(localized: "Pequenos")
        case .normal: String(localized: "Normal")
        case .rigido: String(localized: "Rígido")
        }
    }

    private static func name(_ set: CommandSet) -> String {
        switch set {
        case .classic: "VIVO / MORTO"
        case .school: "LEVANTA / AGACHA"
        case .en: "UP / DOWN"
        }
    }
}
