import AganhaCore
import SwiftUI

/// Tela inicial: o logo, os bonecos, um botão enorme de JOGAR e pouca coisa mais. Os ajustes ficam guardados
/// (e escondidos na engrenagem); na primeira vez já vêm escolhidos: pontuação, Sapeca, 10 rodadas, comandos duplos.
struct HomeView: View {
    @Bindable var loop: GameLoop
    /// `true` para o treino solo.
    let onPlay: (Bool) -> Void
    let onDiagnostic: () -> Void
    @State private var showSettings = false
    @State private var showMoments = false
    @State private var showTV = false
    @State private var mirroring = MirroringMonitor()
    @State private var pulse = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            FloatingCoins().ignoresSafeArea()
            GeometryReader { geo in
                let compact = geo.size.height < 700
                VStack(spacing: compact ? 10 : 18) {
                    topBar
                    Spacer(minLength: 0)
                    logo(compact: compact)
                    AvatarStage { time, aspect in mascots(time: time, aspect: aspect) }
                        .frame(height: min(geo.size.height * 0.34, 300))
                    modePicker
                    playButton
                    secondaryButtons
                    summary
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
        }
        .foregroundStyle(.white)
        .sheet(isPresented: $showSettings) {
            SettingsView(loop: loop, onDiagnostic: { showSettings = false; onDiagnostic() }, onClose: { showSettings = false })
        }
        .sheet(isPresented: $showTV) { ConnectTVView(loop: loop) }
        .fullScreenCover(isPresented: $showMoments) { MomentsView(loop: loop, onClose: { showMoments = false }) }
        .onAppear { pulse = true }
    }

    // MARK: - Partes

    private var topBar: some View {
        HStack {
            Button { showTV = true } label: {
                Label(loop.tv.connectedScreens > 0 || mirroring.isMirroring ? "TV conectada" : "Conectar TV", systemImage: "tv")
                    .font(.subheadline.weight(.bold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.14), in: .capsule)
            }
            Spacer()
            Button { showSettings = true } label: {
                Image(systemName: "gearshape.fill").font(.title2).padding(10).background(.white.opacity(0.14), in: .circle)
            }
            .accessibilityLabel("Ajustes")
        }
    }

    private func logo(compact: Bool) -> some View {
        VStack(spacing: 2) {
            Text("Aganha!")
                .font(.system(size: compact ? 64 : 84, weight: .black, design: .rounded))
                .foregroundStyle(LinearGradient(colors: [Color(hex: "#FFE27A"), Color.aganhaYellow], startPoint: .top, endPoint: .bottom))
                .shadow(color: Color(hex: "#B5791A"), radius: 0, x: 0, y: 5)
                .shadow(color: .black.opacity(0.4), radius: 12, y: 10)
            Text("Levanta, agacha e vê quem é mais rápido!")
                .font(.system(size: 19, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.aganhaCream.opacity(0.9))
                .multilineTextAlignment(.center)
        }
    }

    private var modePicker: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                modeButton(.score, title: String(localized: "Pontuação"), symbol: "coin")
                modeButton(.elimination, title: String(localized: "Eliminação"), symbol: "🏆")
            }
            Text(loop.settings.mode == .score ? "Quem reage mais rápido junta mais moedas."
                 : "Errou, saiu! O último que fica vence.")
                .font(.callout)
                .foregroundStyle(Color.aganhaCream.opacity(0.8))
        }
    }

    private func modeButton(_ mode: GameMode, title: String, symbol: String) -> some View {
        let selected = loop.settings.mode == mode
        return Button { withAnimation(.spring(duration: 0.25)) { loop.settings.mode = mode } } label: {
            HStack(spacing: 6) {
                if symbol == "coin" {
                    Image(systemName: "bitcoinsign.circle.fill").foregroundStyle(Color(hex: "#E0A100"))
                } else {
                    Text(symbol)
                }
                Text(title).font(.system(size: 19, weight: .heavy, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(selected ? Color.aganhaYellow : .white.opacity(0.14), in: .capsule)
            .foregroundStyle(selected ? Color(hex: "#1B1433") : .white)
            .overlay { Capsule().stroke(.white.opacity(selected ? 0 : 0.25), lineWidth: 1.5) }
        }
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var playButton: some View {
        Button { onPlay(false) } label: {
            HStack(spacing: 12) {
                Image(systemName: "play.fill").font(.system(size: 34, weight: .black))
                Text("JOGAR").font(.system(size: 44, weight: .black, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(LinearGradient(colors: [Color(hex: "#5BE7C4"), Color(hex: "#1FA98A")], startPoint: .top, endPoint: .bottom),
                        in: .capsule)
            .overlay { Capsule().stroke(.white.opacity(0.55), lineWidth: 3) }
            .shadow(color: Color(hex: "#0B6B58"), radius: 0, x: 0, y: 7)
            .shadow(color: .black.opacity(0.35), radius: 14, y: 12)
            .foregroundStyle(.white)
        }
        .scaleEffect(pulse ? 1.03 : 1)
        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
    }

    private var secondaryButtons: some View {
        HStack(spacing: 12) {
            secondary("Jogar sozinho", symbol: "person.fill") { onPlay(true) }
            secondary("Momentos", symbol: "play.rectangle.on.rectangle.fill") { showMoments = true }
        }
    }

    private func secondary(_ title: LocalizedStringKey, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(.white.opacity(0.16), in: .capsule)
        }
    }

    private var summary: some View {
        Button { showSettings = true } label: {
            HStack(spacing: 6) {
                Text(summaryText)
                Image(systemName: "chevron.right").font(.caption.weight(.bold))
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.aganhaCream.opacity(0.75))
        }
    }

    private var summaryText: String {
        let settings = loop.settings
        let level = switch settings.difficulty {
        case .tranquilo: String(localized: "Tranquilo")
        case .sapeca: String(localized: "Sapeca")
        case .furacao: String(localized: "Furacão")
        }
        let detail = settings.mode == .score ? String(localized: "\(settings.scoreRounds) rodadas") : String(localized: "1 erro e sai")
        return "\(level) · \(detail)" + (settings.doubles ? " · " + String(localized: "comandos duplos") : "")
    }

    private func mascots(time: Double, aspect: Double) -> [AvatarFigure] {
        let host = loop.settings.host
        var hostFigure = AvatarFigure.player(name: nil, colorHex: host.shirtHex, x: 0.5, spec: AvatarPoses.idle(time), aspect: aspect,
                                             scale: 1.1)
        hostFigure.host = host
        return [
            AvatarFigure.player(name: nil, colorHex: "#FFC845", x: 0.22, spec: AvatarPoses.dance(time), mood: .win, crown: true,
                                look: .girl, aspect: aspect, scale: 1.0),
            AvatarFigure.player(name: nil, colorHex: "#36C9A6", x: 0.78, spec: AvatarPoses.dance(time + 0.55), mood: .win, aspect: aspect,
                                scale: 1.0),
            hostFigure
        ]
    }
}

/// Moedinhas boiando de leve no fundo da tela inicial.
private struct FloatingCoins: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                for index in 0..<9 {
                    let phase = Double(index) * 0.77
                    let x = size.width * (0.08 + 0.84 * ((Double(index) * 0.37).truncatingRemainder(dividingBy: 1)))
                    let y = size.height * ((time * 0.03 + Double(index) * 0.11).truncatingRemainder(dividingBy: 1.1) - 0.05)
                    let radius = 7 + CGFloat(index % 3) * 4
                    let squash = abs(cos(time * 2 + phase))
                    let rect = CGRect(x: x - radius * squash, y: size.height - y - radius, width: radius * 2 * squash, height: radius * 2)
                    ctx.fill(Path(ellipseIn: rect), with: .color(Color(hex: "#FFD76A").opacity(0.55)))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#Preview("Tela inicial", traits: .landscapeLeft) {
    HomeView(loop: GameLoop(), onPlay: { _ in }, onDiagnostic: {})
        .preferredColorScheme(.dark)
}
