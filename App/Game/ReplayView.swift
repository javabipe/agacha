import AganhaCore
import AganhaVision
import AVFoundation
import SwiftUI

/// "Alguém errou!": como numa chamada de vídeo, o replay dos jogadores ocupa a tela toda e o que a tia
/// pediu fica num card pequeno no canto. Depois vêm "Foi injusto!" e "Continuar" (segue sozinho).
struct EliminatedView: View {
    let loop: GameLoop
    let info: ResultInfo

    private var commandSet: CommandSet { loop.state.config?.commandSet ?? loop.settings.commandSet }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let asset = loop.replayAsset {
                ReplayVideoView(asset: asset).ignoresSafeArea()
            } else {
                skeletonFallback
            }
            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    title
                    Spacer()
                    GameCard(command: info.result.command, commandSet: commandSet)
                }
                Spacer()
                panel
            }
            .padding(20)
        }
    }

    private var title: some View {
        Text(info.result.isTie ? "Todos erraram juntos!" : "Alguém errou!")
            .font(.system(size: 34, weight: .black, design: .rounded))
            .foregroundStyle(Color.aganhaYellow)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.black.opacity(0.55), in: .capsule)
    }

    /// Quem errou, o que o juiz mediu e os botões.
    private var panel: some View {
        VStack(spacing: 12) {
            ForEach(info.result.wrong, id: \.self) { slot in
                VStack(spacing: 4) {
                    SlotChip(slot: slot, name: loop.name(for: slot), detail: loop.statusDetail(for: slot))
                    if let text = measurement(for: slot) {
                        Text(text).font(.caption.monospacedDigit()).foregroundStyle(.white.opacity(0.8))
                    }
                }
            }
            if info.isManual { actions }
        }
        .padding(16)
        .frame(maxWidth: 560)
        .background(.black.opacity(0.6), in: .rect(cornerRadius: 20))
    }

    /// "mediu 0,36 · precisava ≤ 0,30": ajuda a ver se o erro foi do jogador ou da calibração.
    private func measurement(for slot: ChildSlot) -> String? {
        guard let index = info.result.details[slot]?.crouchIndex, let rules = loop.state.config?.rules else { return nil }
        let measured = index.formatted(.number.precision(.fractionLength(2)))
        let needed = info.result.command.word == .up ? "≤ \(rules.standMax)" : "≥ \(rules.crouchMin)"
        return "mediu \(measured) · precisava \(needed)"
    }

    /// Enquanto o vídeo não fica pronto (ou se estiver desligado), mostra o replay em esqueleto.
    private var skeletonFallback: some View {
        VStack(spacing: 16) {
            if loop.replayPending { ProgressView("Preparando o replay…").tint(.white).foregroundStyle(.white) }
            HStack(spacing: 12) {
                ForEach(info.result.wrong, id: \.self) { slot in
                    ForEach(Array((info.replays[slot] ?? []).enumerated()), id: \.offset) { _, skeleton in
                        SkeletonThumbnail(skeleton: skeleton, color: SlotPalette.color(for: slot))
                            .frame(width: 120, height: 170)
                            .background(.white.opacity(0.08), in: .rect(cornerRadius: 12))
                    }
                }
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
    }
}

/// Card pequeno com o que a tia pediu (palavra, cor e gesto), como a tela dos jogadores mostrava.
private struct GameCard: View {
    let command: Command
    let commandSet: CommandSet

    var body: some View {
        VStack(spacing: 4) {
            Text(commandSet.text(for: command.word))
                .font(.system(size: 30, weight: .black, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .foregroundStyle(.white)
            TiaView(gesture: command.gesture)
                .frame(width: 110, height: 110)
            if command.isTrick {
                Text("Truque!").font(.caption.weight(.bold)).foregroundStyle(.white)
            }
        }
        .padding(10)
        .frame(width: 150)
        .background(Color(hex: commandSet.colorHex(for: command.word)), in: .rect(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.8), lineWidth: 2) }
        .shadow(radius: 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("A tia pediu \(commandSet.text(for: command.word))")
    }
}

/// Vídeo da rodada em tela cheia (sem som, em loop). Existe só até o replay terminar.
private struct ReplayVideoView: UIViewRepresentable {
    let asset: AVAsset

    final class Coordinator {
        var player: AVQueuePlayer?
        var looper: AVPlayerLooper?
    }

    class PlayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer? { layer as? AVPlayerLayer }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.backgroundColor = .black
        let player = AVQueuePlayer()
        player.isMuted = true
        context.coordinator.player = player
        context.coordinator.looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(asset: asset))
        view.playerLayer?.player = player
        view.playerLayer?.videoGravity = .resizeAspect
        player.play()
        return view
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {}

    static func dismantleUIView(_ uiView: PlayerView, coordinator: Coordinator) {
        coordinator.player?.pause()
        coordinator.looper?.disableLooping()
        uiView.playerLayer?.player = nil
    }
}
