import SwiftUI

/// "Momentos": as partidas salvas neste aparelho (pôster de avatares e fotos reais) e, abaixo, exemplos de como vai ficar o
/// compartilhamento. Os salvos nunca saem do aparelho sem um adulto compartilhar.
struct MomentsView: View {
    let loop: GameLoop
    let onClose: () -> Void
    @State private var saved: [Moment] = []
    @State private var sharing: Moment?
    @State private var deleting: Moment?
    private let columns = [GridItem(.adaptive(minimum: 220), spacing: 16)]

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Text("Momentos").font(.system(size: 34, weight: .black, design: .rounded)).foregroundStyle(Color.aganhaYellow)
                    Spacer()
                    Button("Voltar", action: onClose).buttonStyle(.borderedProminent).tint(Color(hex: "#36C9A6"))
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        section("Meus momentos", note: loop.settings.saveMoments
                                ? "Guardados só neste aparelho. Dá para desligar ou apagar em Ajustes."
                                : "Guardar momentos está desligado nos Ajustes.")
                        if saved.isEmpty {
                            Text("Jogue uma partida: o pôster dos avatares e as fotos reais aparecem aqui.")
                                .font(.callout)
                                .foregroundStyle(Color.aganhaCream.opacity(0.75))
                                .padding(.vertical, 8)
                        } else {
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(saved) { moment in
                                    MomentCard(moment: moment, onShare: { sharing = moment }, onDelete: { deleting = moment })
                                }
                            }
                        }
                        section("Exemplos", note: "Dados de exemplo: depois aqui ficam os vídeos de verdade da sua turma.")
                            .padding(.top, 16)
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(Moment.samples) { moment in MomentCard(moment: moment, onShare: { sharing = moment }) }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
        }
        .foregroundStyle(.white)
        .onAppear(perform: reload)
        .sheet(item: $sharing) { moment in ShareClipView(moment: moment, onClose: { sharing = nil }) }
        .confirmationDialog("Apagar este momento?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                            titleVisibility: .visible) {
            Button("Apagar", role: .destructive) {
                if let deleting { MomentStore.shared.delete(deleting.id) }
                deleting = nil
                reload()
            }
            Button("Cancelar", role: .cancel) { deleting = nil }
        } message: {
            Text("O pôster e as fotos reais deste momento serão apagados do aparelho.")
        }
    }

    private func section(_ title: LocalizedStringKey, note: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.title2.weight(.heavy))
            Text(note).font(.footnote).foregroundStyle(Color.aganhaCream.opacity(0.7))
        }
    }

    private func reload() {
        saved = MomentStore.shared.list()
    }
}

#Preview("Momentos", traits: .landscapeLeft) {
    MomentsView(loop: GameLoop(), onClose: {}).preferredColorScheme(.dark)
}
