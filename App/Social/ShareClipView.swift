import AganhaSocial
import AVKit
import SwiftUI
import UIKit

/// Folha de compartilhamento (SIMULAÇÃO): prévia vertical, legenda e destinos.
/// Nada sai do aparelho ainda; os botões só mostram como o fluxo vai ser.
struct ShareClipView: View {
    enum Stage: Equatable {
        case choosing
        case sending(SocialNetwork, progress: Double, step: String)
        case done(SocialNetwork)
    }

    enum Media: Hashable {
        case photo, video
    }

    let moment: Moment
    let onClose: () -> Void
    @State private var media = Media.video
    @State private var cover: UIImage?
    @State private var playing = false
    @State private var caption = ""
    @State private var showRealKids = false
    @State private var stage = Stage.choosing
    @State private var systemSheet = false
    @State private var shareItems: [Any] = []
    @State private var confirmReal = false
    @State private var shotIndex = 0

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    header
                    HStack(alignment: .top, spacing: 20) {
                        VStack(spacing: 10) { preview; mediaPicker }.frame(maxWidth: 230)
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
        .onAppear {
            if caption.isEmpty { caption = Self.suggestedCaption(for: moment) }
            if !hasVideo { media = .photo }
        }
        .task(id: moment.videoURL) { if let url = moment.videoURL { cover = await VideoThumbnail.image(for: url) } }
        .fullScreenCover(isPresented: $playing) {
            if let url = moment.videoURL { VideoPlayerSheet(url: url, onClose: { playing = false }) }
        }
        .sheet(isPresented: $systemSheet) { ActivityView(items: shareItems) }
        .alert("Mostrar as crianças de verdade?", isPresented: $confirmReal) {
            Button("Sim, tenho autorização") { showRealKids = true }
            Button("Não", role: .cancel) {}
        } message: {
            Text("A foto real mostra o rosto de quem jogou. Só compartilhe com a autorização dos responsáveis de cada criança.")
        }
    }

    private var hasVideo: Bool { moment.videoURL != nil || moment.isSample }

    /// Prévia do que vai ser compartilhado: a foto/pôster ou a capa do vídeo (que toca ao tocar).
    @ViewBuilder private var preview: some View {
        if media == .video, let cover, moment.videoURL != nil {
            Button { playing = true } label: { VideoCover(image: cover, duration: moment.durationText) }
                .buttonStyle(.plain)
                .accessibilityLabel("Tocar o vídeo")
        } else {
            MomentPreview(moment: moment, photo: media == .photo ? photo : nil)
                .overlay(alignment: .topTrailing) {
                    if media == .video && moment.isSample {
                        Label(moment.durationText, systemImage: "play.fill").font(.caption.weight(.bold)).padding(6)
                            .background(.black.opacity(0.55), in: .capsule).padding(8)
                    }
                }
        }
    }

    private var mediaPicker: some View {
        VStack(spacing: 4) {
            Picker("Compartilhar", selection: $media) {
                Text("Foto").tag(Media.photo)
                Text("Vídeo").tag(Media.video)
            }
            .pickerStyle(.segmented)
            .disabled(!hasVideo)
            if !hasVideo {
                Text("O vídeo deste momento ainda não está pronto ou não foi guardado.")
                    .font(.caption2)
                    .foregroundStyle(Color.aganhaCream.opacity(0.65))
            }
        }
    }

    /// O arquivo que sai: o vídeo de avatares ou a imagem (avatares ou foto real) com placar e marca.
    private func currentFile() -> (url: URL, kind: ShareItem.Kind)? {
        if media == .video, let url = moment.videoURL { return (url, .video) }
        return exportImage().map { ($0, .image) }
    }

    private var photo: UIImage? {
        guard showRealKids, moment.shotURLs.indices.contains(shotIndex) else { return nil }
        return UIImage(contentsOfFile: moment.shotURLs[shotIndex].path)
    }

    private var realCaption: String {
        if moment.shotURLs.isEmpty {
            return moment.isSample ? String(localized: "Os exemplos não têm foto real.")
                : String(localized: "Não há foto real guardada deste momento.")
        }
        return showRealKids ? String(localized: "Mostra o rosto de quem jogou: só com a autorização dos responsáveis.")
            : String(localized: "Desligado: o vídeo mostra só os avatares (sem rostos reais).")
    }

    /// Imagem final do momento (avatares ou foto real, com placar e marca), pronta para o share sheet.
    private func exportImage() -> URL? {
        let view = MomentPreview(moment: moment, photo: photo, frozenAt: 0.25).frame(width: 360, height: 640)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        guard let data = renderer.uiImage?.pngData() else { return nil }
        let url = FileManager.default.temporaryDirectory.appending(path: "Aganha-\(moment.id.uuidString.prefix(8)).png")
        return (try? data.write(to: url)) != nil ? url : nil
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
                .textFieldStyle(.plain)
                .padding(12)
                .background(.white, in: .rect(cornerRadius: 12))
                .foregroundStyle(Color(hex: "#1B1433"))
                .tint(Color(hex: "#1FA98A"))
            if media == .photo { realToggle }
        }
    }

    private var realToggle: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: Binding(get: { showRealKids }, set: { if $0 { confirmReal = true } else { showRealKids = false } })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mostrar as crianças de verdade").font(.headline)
                    Text(realCaption).font(.caption).foregroundStyle(showRealKids ? Color(hex: "#FFC845") : Color.aganhaCream.opacity(0.7))
                }
            }
            .disabled(moment.shotURLs.isEmpty)
            if showRealKids, moment.shotURLs.count > 1 {
                Button("Trocar foto (\(shotIndex + 1)/\(moment.shotURLs.count))") { shotIndex = (shotIndex + 1) % moment.shotURLs.count }
                    .buttonStyle(.bordered)
            }
        }
    }

    private var destinations: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
            ForEach(SocialNetwork.allCases) { network in
                Button { send(to: network) } label: {
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
                let what = media == .video ? String(localized: "o vídeo") : String(localized: "a foto")
                Text("Com a integração ligada, aqui o \(network.title) abriria com \(what).").font(.callout)
                Button("Compartilhar em outro lugar") { stage = .choosing }.buttonStyle(.bordered)
            }
            .padding(16)
            .background(.black.opacity(0.35), in: .rect(cornerRadius: 16))
        }
    }

    private func send(to network: SocialNetwork) {
        if network == .more {
            shareItems = [caption] + (currentFile().map { [$0.url] } ?? [])
            systemSheet = true
            return
        }
        Task {
            let preparing = media == .video ? String(localized: "Preparando o vídeo vertical 9:16…")
                : String(localized: "Preparando a imagem…")
            let steps = [preparing, String(localized: "Colocando o placar e a marca do jogo…"),
                         String(localized: "Abrindo \(network.title)…")]
            for (index, step) in steps.enumerated() {
                stage = .sending(network, progress: Double(index) / Double(steps.count), step: step)
                try? await Task.sleep(for: .milliseconds(700))
            }
            // A integração de verdade (SDK ou esquema de URL) já está ligada aqui, mas desligada: responde "simulação".
            if let file = currentFile() {
                let item = ShareItem(fileURL: file.url, kind: file.kind, caption: caption)
                _ = await SocialShareCenter.shared.share(item, to: network.platform)
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
