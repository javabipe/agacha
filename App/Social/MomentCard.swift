import SwiftUI
import UIKit

/// Cartão de um momento na tela Momentos: pôster de avatares (ou a foto real, com o seletor), título e ações.
struct MomentCard: View {
    let moment: Moment
    let onShare: () -> Void
    /// Só nos momentos salvos (os de exemplo não se apagam).
    var onDelete: (() -> Void)?
    @State private var showReal = false
    @State private var liked = false

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
    }

    @ViewBuilder private var preview: some View {
        if showReal, let shot {
            MomentPreview(moment: moment, photo: shot)
        } else if !moment.isSample, let poster {
            Image(uiImage: poster).resizable().scaledToFit().clipShape(.rect(cornerRadius: 22))
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
