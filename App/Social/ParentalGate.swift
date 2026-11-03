import SwiftUI

/// Portão para adultos (exigido pela App Store em apps da categoria Kids antes de links, redes sociais e compartilhamento):
/// uma conta de multiplicar que uma criança pequena não resolve sozinha.
struct ParentalGateView: View {
    let onPass: () -> Void
    let onCancel: () -> Void
    @State private var a = Int.random(in: 4...9)
    @State private var b = Int.random(in: 4...9)
    @State private var answer = ""
    @State private var wrong = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "lock.shield.fill").font(.system(size: 54)).foregroundStyle(Color.aganhaYellow)
            Text("Só para adultos").font(.system(size: 30, weight: .black, design: .rounded))
            Text("Para compartilhar, resolva a conta:").font(.headline).foregroundStyle(Color.aganhaCream.opacity(0.85))
            Text("\(a) × \(b) = ?").font(.system(size: 44, weight: .heavy, design: .rounded))
            TextField("Resposta", text: $answer)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .font(.title2)
                .frame(maxWidth: 200)
                .multilineTextAlignment(.center)
                .focused($focused)
            if wrong { Text("Não é essa. Tente de novo.").font(.callout).foregroundStyle(Color(hex: "#FF8A80")) }
            HStack(spacing: 14) {
                Button("Cancelar", action: onCancel).buttonStyle(.bordered)
                Button("Confirmar", action: check).buttonStyle(.borderedProminent).tint(Color(hex: "#36C9A6"))
            }
            .controlSize(.large)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
        .foregroundStyle(.white)
        .onAppear { focused = true }
    }

    private func check() {
        if Int(answer.trimmingCharacters(in: .whitespaces)) == a * b {
            onPass()
        } else {
            wrong = true
            answer = ""
            a = Int.random(in: 4...9)
            b = Int.random(in: 4...9)
        }
    }
}
