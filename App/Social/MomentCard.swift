import SwiftUI
import UIKit

/// Cartão de um momento na tela Momentos: pôster de avatares (ou a foto real, com o seletor), título e ações.
struct MomentCard: View {
    let moment: Moment
    let onShare: () -> Void
    /// Só nos momentos salvos (os de exemplo não se apagam).
    var onDelete: (() -> Void)?
    /// O vídeo de avatares deste momento ainda está sendo gerado.
    var isGenerating = false
    @State private var showReal = false
    @State private var liked = false
    @State private var cover: UIImage?
    @State private var playing = false

    private var shot: UIImage? { moment.shotURLs.first.flatMap { UIImage(contentsOfFile: $0.path) } }
    private var poster: UIImage? { moment.posterURL.flatMap { UIImage(contentsOfFile: $0.path) } }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            preview
            if shot != nil {
                Picker("Imagem", selection: $showReal) {
                    Text("Avatares").tag(false)
                    Text("Foto real").tag(true)
                }
                .pickerStyle(.segmented)
            }
            Text(moment.title).font(.headline)
            Text("\(moment.place) · \(moment.ago)").font(.caption).foregroundStyle(Color.aganhaCream.opacity(0.7))
            actions
        }
        .padding(10)
        .background(.black.opacity(0.28), in: .rect(cornerRadius: 22))
        .task(id: moment.videoURL) {
            if let url = moment.videoURL { cover = await VideoThumbnail.image(for: url) }
        }
    }

    @ViewBuilder private var preview: some View {
        if showReal, let shot {
            MomentPreview(moment: moment, photo: shot)
        } else if let cover, let url = moment.videoURL {
            Button { playing = true } label: { VideoCover(image: cover, duration: moment.durationText) }
                .buttonStyle(.plain)
                .accessibilityLabel("Tocar o vídeo")
                .fullScreenCover(isPresented: $playing) { VideoPlayerSheet(url: url, onClose: { playing = false }) }
        } else if !moment.isSample, let poster {
            Image(uiImage: poster).resizable().scaledToFit().clipShape(.rect(cornerRadius: 22))
                .overlay(alignment: .bottom) {
                    if isGenerating {
                        Label("Gerando o vídeo…", systemImage: "film")
                            .font(.caption.weight(.bold))
                            .padding(8)
                            .background(.black.opacity(0.65), in: .capsule)
                            .padding(10)
                    }
                }
        } else {
            MomentPreview(moment: moment, showsOverlay: moment.isSample ? false : true)
                .overlay(alignment: .topTrailing) {
                    if moment.isSample {
                        Label(moment.durationText, systemImage: "play.fill")
                            .font(.caption.weight(.bold))
                            .padding(6)
                            .background(.black.opacity(0.55), in: .capsule)
                            .padding(8)
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    if moment.isSample {
                        Text(moment.headline).font(.system(size: 18, weight: .black, design: .rounded)).shadow(radius: 4).padding(10)
                    }
                }
        }
    }

    private var actions: some View {
        HStack {
            if moment.isSample {
                Button { liked.toggle() } label: {
                    Label(Moment.compact(moment.likes + (liked ? 1 : 0)), systemImage: liked ? "heart.fill" : "heart")
                        .foregroundStyle(liked ? Color(hex: "#FF7AB8") : .white)
                }
                Spacer()
                Label(Moment.compact(moment.views), systemImage: "eye").font(.caption).foregroundStyle(Color.aganhaCream.opacity(0.7))
            } else {
                if let onDelete {
                    Button(role: .destructive, action: onDelete) { Image(systemName: "trash") }
                        .accessibilityLabel("Apagar este momento")
                }
                Spacer()
            }
            Button(action: onShare) { Image(systemName: "square.and.arrow.up") }
                .accessibilityLabel("Compartilhar")
        }
        .font(.subheadline.weight(.semibold))
    }
}
