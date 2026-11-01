import AganhaCore
import SwiftUI

struct MenuView: View {
    @Bindable var loop: GameLoop
    let onPlay: () -> Void
    let onDiagnostic: () -> Void

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

                    Button("Diagnóstico da câmera", action: onDiagnostic)
                        .foregroundStyle(Color.aganhaCream.opacity(0.7))
                }
                .frame(maxWidth: 560)
                .padding(24)
                .frame(maxWidth: .infinity)
            }
        }
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
