import SwiftUI

/// "Momentos": os melhores vídeos da turma (SIMULAÇÃO com dados de exemplo), com curtidas e botão de compartilhar.
struct MomentsView: View {
    let onClose: () -> Void
    @State private var sharing: Moment?
    @State private var liked: Set<UUID> = []

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Momentos").font(.system(size: 34, weight: .black, design: .rounded)).foregroundStyle(Color.aganhaYellow)
                        Text("Exemplos: depois aqui ficam os vídeos de verdade da sua turma.")
                            .font(.footnote)
                            .foregroundStyle(Color.aganhaCream.opacity(0.7))
                    }
                    Spacer()
                    Button("Voltar", action: onClose).buttonStyle(.borderedProminent).tint(Color(hex: "#36C9A6"))
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 16)], spacing: 16) {
                        ForEach(Moment.samples) { moment in card(moment) }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
        }
        .foregroundStyle(.white)
        .sheet(item: $sharing) { moment in ShareClipView(moment: moment, onClose: { sharing = nil }) }
    }

    private func card(_ moment: Moment) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            MomentPreview(moment: moment, showsOverlay: false)
                .overlay(alignment: .topTrailing) {
                    Label(moment.durationText, systemImage: "play.fill")
                        .font(.caption.weight(.bold))
                        .padding(6)
                        .background(.black.opacity(0.55), in: .capsule)
                        .padding(8)
                }
                .overlay(alignment: .bottomLeading) {
                    Text(moment.headline).font(.system(size: 18, weight: .black, design: .rounded)).shadow(radius: 4).padding(10)
                }
            Text(moment.title).font(.headline)
            Text("\(moment.place) · \(moment.ago)").font(.caption).foregroundStyle(Color.aganhaCream.opacity(0.7))
            HStack {
                Button { toggleLike(moment) } label: {
                    Label(Moment.compact(moment.likes + (liked.contains(moment.id) ? 1 : 0)),
                          systemImage: liked.contains(moment.id) ? "heart.fill" : "heart")
                        .foregroundStyle(liked.contains(moment.id) ? Color(hex: "#FF7AB8") : .white)
                }
                Spacer()
                Label(Moment.compact(moment.views), systemImage: "eye").font(.caption).foregroundStyle(Color.aganhaCream.opacity(0.7))
                Button { sharing = moment } label: { Image(systemName: "square.and.arrow.up") }
                    .accessibilityLabel("Compartilhar")
            }
            .font(.subheadline.weight(.semibold))
        }
        .padding(10)
        .background(.black.opacity(0.28), in: .rect(cornerRadius: 22))
    }

    private func toggleLike(_ moment: Moment) {
        if liked.contains(moment.id) { liked.remove(moment.id) } else { liked.insert(moment.id) }
    }
}

#Preview("Momentos", traits: .landscapeLeft) {
    MomentsView(onClose: {}).preferredColorScheme(.dark)
}
