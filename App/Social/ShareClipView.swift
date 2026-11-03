import SwiftUI
import UIKit

/// Folha de compartilhamento (SIMULAÇÃO): prévia vertical, legenda, destinos e portão para adultos.
/// Nada sai do aparelho ainda; os botões só mostram como o fluxo vai ser.
struct ShareClipView: View {
    enum Stage: Equatable {
        case choosing
        case sending(SocialNetwork, progress: Double, step: String)
        case done(SocialNetwork)
    }

    let moment: Moment
    let onClose: () -> Void
    @State private var caption = ""
    @State private var showRealKids = false
    @State private var pending: SocialNetwork?
    @State private var stage = Stage.choosing
    @State private var systemSheet = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    header
                    HStack(alignment: .top, spacing: 20) {
                        MomentPreview(moment: moment).frame(maxWidth: 230)
                        VStack(alignment: .leading, spacing: 14) { options; destinations }
                    }
                    statusArea
                    Text("Simulação com dados de exemplo: a ligação com cada rede vem depois.")
                        .font(.footnote)
                        .foregroundStyle(Color.aganhaCream.opacity(0.65))
                }
                .padding(24)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
        }
        .foregroundStyle(.white)
        .onAppear { if caption.isEmpty { caption = Self.suggestedCaption(for: moment) } }
        .sheet(item: $pending) { network in
            ParentalGateView(onPass: { pending = nil; send(to: network) }, onCancel: { pending = nil })
        }
        .sheet(isPresented: $systemSheet) { ActivityView(items: [caption]) }
    }

    static func suggestedCaption(for moment: Moment) -> String {
        let who = moment.winners.first?.name ?? String(localized: "Todo mundo")
        return String(localized: "\(who) foi o mais rápido no Aganha! 🪙 Você consegue ganhar? #AganhaChallenge #Aganha")
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Compartilhar momento").font(.system(size: 30, weight: .black, design: .rounded)).foregroundStyle(Color.aganhaYellow)
                Text("\(moment.title) · \(moment.durationText)").font(.callout).foregroundStyle(Color.aganhaCream.opacity(0.8))
            }
            Spacer()
            Button("Fechar", action: onClose).buttonStyle(.bordered)
        }
    }

    private var options: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Legenda").font(.headline)
            TextField("Legenda", text: $caption, axis: .vertical)
                .lineLimit(3...5)
                .textFieldStyle(.roundedBorder)
                .foregroundStyle(.black)
            Toggle(isOn: $showRealKids) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mostrar as crianças de verdade").font(.headline)
                    Text(showRealKids ? "Precisa da autorização dos responsáveis de cada criança que aparece."
                         : "Desligado: o vídeo mostra só os avatares (sem rostos reais).")
                        .font(.caption)
                        .foregroundStyle(showRealKids ? Color(hex: "#FFC845") : Color.aganhaCream.opacity(0.7))
                }
            }
        }
    }

    private var destinations: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
            ForEach(SocialNetwork.allCases) { network in
                Button { pending = network } label: {
                    Label(network.title, systemImage: network.symbol)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(LinearGradient(colors: network.gradient, startPoint: .topLeading, endPoint: .bottomTrailing),
                                    in: .rect(cornerRadius: 14))
                        .foregroundStyle(.white)
                }
                .disabled(stage != .choosing)
            }
        }
    }

    @ViewBuilder private var statusArea: some View {
        switch stage {
        case .choosing:
            EmptyView()
        case let .sending(network, progress, step):
            VStack(spacing: 8) {
                ProgressView(value: progress).tint(Color.aganhaYellow)
                Text(step).font(.headline)
                Text(network.integration).font(.footnote).foregroundStyle(Color.aganhaCream.opacity(0.7))
            }
            .padding(16)
            .background(.black.opacity(0.35), in: .rect(cornerRadius: 16))
        case let .done(network):
            VStack(spacing: 8) {
                Text("✅ Pronto! (simulação)").font(.title3.weight(.heavy))
                Text("Com a integração ligada, aqui o \(network.title) abriria com o vídeo.").font(.callout)
                Button("Compartilhar em outro lugar") { stage = .choosing }.buttonStyle(.bordered)
            }
            .padding(16)
            .background(.black.opacity(0.35), in: .rect(cornerRadius: 16))
        }
    }

    private func send(to network: SocialNetwork) {
        if network == .more { systemSheet = true; return }
        Task {
            let steps = [String(localized: "Montando o vídeo vertical 9:16…"), String(localized: "Colocando o placar e a marca do jogo…"),
                         String(localized: "Abrindo \(network.title)…")]
            for (index, step) in steps.enumerated() {
                stage = .sending(network, progress: Double(index) / Double(steps.count), step: step)
                try? await Task.sleep(for: .milliseconds(700))
            }
            stage = .done(network)
        }
    }
}

extension SocialNetwork: Hashable {}

/// Folha de compartilhamento do iOS (usada no "Mais…").
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

#Preview("Compartilhar", traits: .landscapeLeft) {
    ShareClipView(moment: Moment.samples[1], onClose: {}).preferredColorScheme(.dark)
}
