import SwiftUI

/// Jogadores salvos neste aparelho: ver, apagar um ou apagar tudo.
struct PlayersView: View {
    @Bindable var store: ProfileStore
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDeleteAll = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Guardar rostos neste aparelho", isOn: Binding(
                        get: { store.consent == true },
                        set: { store.consent = $0 ? true : false }
                    ))
                } footer: {
                    Text("Só ficam guardadas impressões do rosto (não são fotos), apenas aqui, sem backup. Desligar apaga tudo.")
                }
                Section("Jogadores") {
                    if store.profiles.isEmpty {
                        Text("Nenhum jogador guardado ainda.").foregroundStyle(.secondary)
                    }
                    ForEach(store.profiles) { profile in
                        VStack(alignment: .leading) {
                            Text(profile.name).font(.headline)
                            Text("Visto em \(profile.lastSeenAt.formatted(date: .abbreviated, time: .omitted))"
                                 + " · \(profile.prints.count) leituras")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets { store.delete(store.profiles[index].id) }
                    }
                }
                if !store.profiles.isEmpty {
                    Section {
                        Button("Apagar todos os jogadores", role: .destructive) { confirmDeleteAll = true }
                    }
                }
            }
            .navigationTitle("Jogadores salvos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Fechar") { dismiss() } }
            .confirmationDialog("Apagar todos os jogadores e rostos guardados?", isPresented: $confirmDeleteAll,
                                titleVisibility: .visible) {
                Button("Apagar tudo", role: .destructive) { store.deleteAll() }
            }
        }
    }
}
