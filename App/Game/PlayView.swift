import AganhaCore
import AganhaVision
import SwiftUI

/// Partida: tela virada para as crianças (palavra gigante, cor de fundo, tia, faixa de status).
struct PlayView: View {
    let loop: GameLoop
    let onQuit: () -> Void
    @State private var confirmQuit = false

    private var commandSet: CommandSet { loop.state.config?.commandSet ?? loop.settings.commandSet }

    var body: some View {
        ZStack {
            Rectangle().fill(background).ignoresSafeArea()
            GeometryReader { geo in
                let landscape = geo.size.width > geo.size.height
                VStack(spacing: 16) {
                    Spacer(minLength: 0)
                    if landscape {
                        HStack(spacing: 24) {
                            TiaView(gesture: loop.shownCommand?.gesture)
                                .frame(maxWidth: geo.size.width * 0.34)
                            word
                        }
                    } else {
                        TiaView(gesture: loop.shownCommand?.gesture)
                            .frame(maxHeight: geo.size.height * 0.4)
                        word
                    }
                    Spacer(minLength: 0)
                    statusStrip
                }
                .padding()
            }
            if let info = loop.resultInfo {
                EliminatedView(loop: loop, info: info)
                    .transition(.opacity)
            }
            VStack {
                HStack {
                    Spacer()
                    Button("Sair", systemImage: "xmark.circle.fill") { confirmQuit = true }
                        .labelStyle(.iconOnly)
                        .font(.title)
                        .foregroundStyle(.white.opacity(0.5))
                        .accessibilityLabel("Sair da partida")
                }
                Spacer()
            }
            .padding()
        }
        .animation(.easeOut(duration: 0.15), value: loop.shownCommand?.number)
        .confirmationDialog("Sair da partida?", isPresented: $confirmQuit, titleVisibility: .visible) {
            Button("Sair", role: .destructive, action: onQuit)
            Button("Continuar jogando", role: .cancel) {}
        }
    }

    private var background: some ShapeStyle {
        if let command = loop.shownCommand { return AnyShapeStyle(Color(hex: commandSet.colorHex(for: command.word))) }
        return AnyShapeStyle(Theme.background)
    }

    @ViewBuilder private var word: some View {
        if let command = loop.shownCommand {
            Text(commandSet.text(for: command.word))
                .font(.system(size: 180, weight: .black, design: .rounded))
                .minimumScaleFactor(0.3)
                .lineLimit(1)
                .foregroundStyle(.white)
                .shadow(radius: 8, y: 4)
        } else if let countdown = loop.countdownText {
            Text(countdown)
                .font(.system(size: 110, weight: .heavy, design: .rounded))
                .minimumScaleFactor(0.3)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.aganhaCream)
        }
    }

    private var statusStrip: some View {
        HStack(spacing: 8) {
            ForEach(loop.state.config?.slots ?? [], id: \.self) { slot in
                SlotChip(slot: slot, isOut: loop.state.players[slot]?.isEliminated ?? false,
                         detail: (loop.state.players[slot]?.isEliminated ?? false) ? "✕" : nil)
            }
        }
    }
}

/// "Alguém errou!": replay em esqueleto, "Foi injusto!" e "Continuar" (segue sozinho depois de alguns segundos).
struct EliminatedView: View {
    let loop: GameLoop
    let info: ResultInfo

    var body: some View {
        ZStack {
            Color.black.opacity(0.78).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    Text(info.result.isTie ? "Todos erraram juntos!" : "Alguém errou!")
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundStyle(Color.aganhaYellow)
                    ForEach(info.result.eliminated, id: \.self) { slot in
                        VStack(spacing: 8) {
                            SlotChip(slot: slot)
                            HStack(spacing: 8) {
                                ForEach(Array((info.replays[slot] ?? []).enumerated()), id: \.offset) { _, skeleton in
                                    SkeletonThumbnail(skeleton: skeleton, color: SlotPalette.color(for: slot))
                                        .frame(width: 110, height: 150)
                                        .background(.white.opacity(0.08), in: .rect(cornerRadius: 12))
                                }
                            }
                        }
                    }
                    if info.isManual { actions }
                }
                .padding(24)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button { loop.unfair() } label: {
                    Text("Foi injusto!").font(.title2.weight(.bold)).frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                Button { loop.continueNow() } label: {
                    Text("Continuar").font(.title2.weight(.bold)).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(hex: "#36C9A6"))
            }
            .controlSize(.large)
            TimelineView(.animation) { _ in
                let progress = max(0, min(1, (info.continueAt - GameLoop.now()) / info.duration))
                GeometryReader { geo in
                    Capsule().fill(.white.opacity(0.2))
                        .overlay(alignment: .leading) {
                            Capsule().fill(Color.aganhaYellow).frame(width: geo.size.width * progress)
                        }
                }
                .frame(height: 8)
            }
        }
        .frame(maxWidth: 520)
    }
}
