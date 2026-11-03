import AganhaCore
import AganhaVision
import SwiftUI

/// Posicionar: enquadrar todos da cabeça aos pés, perguntar o nome de cada um e esperar o gesto de começar.
struct PositioningView: View {
    let loop: GameLoop
    let onBack: () -> Void
    @State private var renaming: ChildSlot?
    @State private var draft = ""
    /// "Salvar" também fecha o alerta; evita tratar o fechamento como "Cancelar".
    @State private var didSave = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            CameraPreview(camera: loop.camera).ignoresSafeArea()
            SkeletonOverlay(analysis: loop.analysis, showPosture: false, names: loop.names).ignoresSafeArea()
            VStack(spacing: 12) {
                banner
                Spacer()
                if loop.step == .naming { recentNames }
                people
                actions
            }
            .padding()
            if let error = loop.cameraError {
                Text(error)
                    .padding()
                    .background(.red.opacity(0.85), in: .rect(cornerRadius: 12))
                    .foregroundStyle(.white)
            }
        }
        .alert(editTitle, isPresented: Binding(get: { editingSlot != nil }, set: { if !$0 { dismissEditor() } })) {
            TextField("Nome", text: $draft)
            Button("Salvar") { saveEditor() }
            Button("Cancelar", role: .cancel) {}
        }
        .onChange(of: loop.typingSlot) { draft = "" }
    }

    /// Quem está sendo editado: o nome que falta digitar ou o que foi tocado.
    private var editingSlot: ChildSlot? { loop.typingSlot ?? renaming }

    private var editTitle: LocalizedStringKey {
        "Nome de \(editingSlot.map { SlotColors.displayName($0) } ?? "")"
    }

    private func saveEditor() {
        didSave = true
        if loop.typingSlot != nil {
            loop.submitTyped(draft)
        } else if let slot = renaming {
            loop.setName(draft, for: slot)
            renaming = nil
        }
        draft = ""
    }

    private func dismissEditor() {
        if didSave {
            didSave = false
            return
        }
        if loop.typingSlot != nil { loop.skipTyping() } else { renaming = nil }
        draft = ""
    }

    private var banner: some View {
        HStack(spacing: 12) {
            if let slot = loop.bannerSlot { Circle().fill(SlotPalette.color(for: slot)).frame(width: 28, height: 28) }
            Text(loop.bannerText)
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(.black.opacity(0.65), in: .rect(cornerRadius: 16))
        .foregroundStyle(.white)
    }

    /// Nomes de partidas anteriores: um toque responde no lugar da voz.
    private var recentNames: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(loop.recentNames, id: \.self) { name in
                    Button(name) { loop.useRecentName(name) }
                        .buttonStyle(.bordered)
                        .tint(.white)
                }
            }
        }
    }

    private var people: some View {
        HStack {
            ForEach(loop.report.people, id: \.slot) { person in
                Button {
                    draft = loop.names[person.slot] ?? ""
                    renaming = person.slot
                } label: {
                    SlotChip(slot: person.slot, name: loop.name(for: person.slot), isOut: !person.isReady,
                             detail: person.isReady ? "✓" : "!")
                        .overlay {
                            if loop.namingSlot == person.slot {
                                Capsule().stroke(.white, lineWidth: 3)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityHint("Toque para mudar o nome")
            }
            if loop.report.extraPeople > 0 {
                Text("+\(loop.report.extraPeople) além de 6").font(.caption).foregroundStyle(.white)
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button("Voltar", systemImage: "chevron.left", action: onBack)
                    .buttonStyle(.bordered)
                if loop.step == .naming || loop.step == .typing {
                    Button("Pular nomes", action: loop.skipNaming)
                        .buttonStyle(.bordered)
                }
                Button {
                    loop.startGame()
                } label: {
                    Text("Começar").font(.title2.weight(.heavy)).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(hex: "#36C9A6"))
                .disabled(!loop.report.allReady)
            }
            .controlSize(.large)
            if !loop.report.allReady, loop.report.people.count >= loop.report.minPlayers {
                Button("Começar mesmo assim") { loop.startGame(anyway: true) }
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
    }
}
