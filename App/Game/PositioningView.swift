import AganhaCore
import AganhaVision
import SwiftUI

/// Antes da partida: conhecer os jogadores de perto, posicionar o aparelho, enquadrar todos e começar.
struct PositioningView: View {
    let loop: GameLoop
    let onBack: () -> Void
    @State private var renaming: ChildSlot?
    @State private var draft = ""

    private var isMeeting: Bool { loop.step == .meeting }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            CameraPreview(camera: loop.camera).ignoresSafeArea()
            if !isMeeting && loop.step != .placing {
                SkeletonOverlay(analysis: loop.analysis, showPosture: false, names: loop.names).ignoresSafeArea()
            }
            if isMeeting && !loop.consentRequest { FaceGuide(progress: loop.faceProgress, hasHint: loop.faceHint != nil) }
            VStack(spacing: 12) {
                banner
                if isMeeting { details }
                Spacer()
                if loop.awaitingName { recentNames }
                people
                actions
            }
            .padding()
            if loop.consentRequest { ConsentCard(onAnswer: loop.answerConsent) }
            if let error = loop.cameraError {
                Text(error)
                    .padding()
                    .background(.red.opacity(0.85), in: .rect(cornerRadius: 12))
                    .foregroundStyle(.white)
            }
        }
        .alert(loop.typingRequest?.title ?? "", isPresented: Binding(
            get: { loop.typingRequest != nil },
            set: { if !$0, loop.typingRequest != nil { loop.resolveTyping(nil) } }
        )) {
            TextField("Nome", text: $draft)
            Button("Salvar") { loop.resolveTyping(draft) }
            Button("Cancelar", role: .cancel) {}
        }
        .onChange(of: loop.typingRequest) { draft = "" }
        .alert("Mudar o nome", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Nome", text: $draft)
            Button("Salvar") { if let slot = renaming { loop.setName(draft, for: slot) } }
            Button("Cancelar", role: .cancel) {}
        }
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

    /// Detalhes do reconhecimento (por enquanto sempre visíveis, para ajustar os limites).
    @ViewBuilder private var details: some View {
        if let debug = loop.recognitionDebug {
            Text(debug)
                .font(.caption.monospacedDigit())
                .padding(6)
                .background(.black.opacity(0.5), in: .rect(cornerRadius: 8))
                .foregroundStyle(.white.opacity(0.8))
        }
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

    @ViewBuilder private var people: some View {
        if isMeeting || loop.step == .placing {
            HStack {
                ForEach(loop.met) { player in
                    Label(player.name, systemImage: player.isNew ? "person.fill.badge.plus" : "person.fill.checkmark")
                        .font(.headline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.55), in: .capsule)
                        .foregroundStyle(.white)
                }
            }
        } else {
            HStack {
                ForEach(loop.report.people, id: \.slot) { person in
                    Button {
                        draft = loop.names[person.slot] ?? ""
                        renaming = person.slot
                    } label: {
                        SlotChip(slot: person.slot, name: loop.name(for: person.slot), isOut: !person.isReady,
                                 detail: person.isReady ? "✓" : "!")
                            .overlay {
                                if loop.namingSlot == person.slot { Capsule().stroke(.white, lineWidth: 3) }
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
    }

    private var actions: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button("Voltar", systemImage: "chevron.left", action: onBack)
                    .buttonStyle(.bordered)
                stepActions
            }
            .controlSize(.large)
            if loop.step == .framing || loop.step == .ready, !loop.report.allReady, loop.report.people.count >= 2 {
                Button("Começar mesmo assim") { loop.startGame(anyway: true) }
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
    }

    @ViewBuilder private var stepActions: some View {
        switch loop.step {
        case .meeting:
            if let candidate = loop.recognizedCandidate {
                Button("Não sou \(candidate.name)") { loop.rejectRecognition() }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
            }
            if !loop.met.isEmpty {
                Button(action: loop.finishMeeting) {
                    Text("Pronto").font(.title2.weight(.heavy)).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(hex: "#36C9A6"))
            }
        case .placing:
            Button(action: loop.confirmPlacement) {
                Text("Já coloquei").font(.title2.weight(.heavy)).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: "#36C9A6"))
        case .naming:
            Button("Pular nomes", action: loop.skipNaming)
                .buttonStyle(.bordered)
            startButton
        case .framing, .identifying, .ready:
            startButton
        }
    }

    private var startButton: some View {
        Button {
            loop.startGame()
        } label: {
            Text("Começar").font(.title2.weight(.heavy)).frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color(hex: "#36C9A6"))
        .disabled(!loop.report.allReady)
    }
}

/// Oval de enquadramento do rosto, com o progresso da leitura.
private struct FaceGuide: View {
    let progress: Double
    let hasHint: Bool

    var body: some View {
        Ellipse()
            .strokeBorder(style: StrokeStyle(lineWidth: 6, dash: progress > 0 ? [] : [14, 10]))
            .foregroundStyle(progress >= 1 ? Color.green : (hasHint ? Color.orange : Color.white))
            .overlay {
                Ellipse().trim(from: 0, to: progress)
                    .stroke(Color.green, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 260, height: 340)
            .animation(.easeOut(duration: 0.2), value: progress)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// Autorização de um adulto para guardar rostos neste aparelho (com uma continha para confirmar que é adulto).
private struct ConsentCard: View {
    let onAnswer: (Bool) -> Void
    @State private var first = Int.random(in: 6...9)
    @State private var second = Int.random(in: 6...9)
    @State private var answer = ""

    private var isAdult: Bool { Int(answer) == first * second }

    var body: some View {
        ZStack {
            Color.black.opacity(0.8).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                Text("Guardar o rosto dos jogadores?")
                    .font(.title.weight(.heavy))
                Text("Para reconhecer quem está jogando sem perguntar o nome toda vez, o Agacha guarda uma \"impressão\" "
                     + "do rosto de cada jogador, **somente neste aparelho**. Não é uma foto e nada é enviado pela internet. "
                     + "Dá para apagar tudo a qualquer momento em Menu › Jogadores salvos.")
                    .font(.body)
                Divider()
                Text("Para um adulto confirmar: quanto é \(first) × \(second)?")
                    .font(.headline)
                TextField("Resposta", text: $answer)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 160)
                HStack(spacing: 12) {
                    Button("Agora não") { onAnswer(false) }
                        .buttonStyle(.bordered)
                    Button("Autorizo") { onAnswer(true) }
                        .buttonStyle(.borderedProminent)
                        .disabled(!isAdult)
                }
                .controlSize(.large)
            }
            .foregroundStyle(.white)
            .padding(24)
            .frame(maxWidth: 560)
        }
    }
}
