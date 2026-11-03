import AganhaCore
import SwiftUI

struct GameOverView: View {
    let result: GameResult
    let name: (ChildSlot) -> String
    /// O app está ouvindo "de novo" / "menu".
    var isListening = false
    var heard = ""
    /// Treino solo: sem campeão nem ranking, só os acertos e o recorde.
    var solo: SoloSummary?
    let onPlayAgain: () -> Void
    let onMenu: () -> Void

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    Text(title)
                        .font(.system(size: 52, weight: .black, design: .rounded))
                        .foregroundStyle(Color.aganhaYellow)
                    if let solo { soloSummary(solo) }
                    ForEach(result.winners, id: \.self) { slot in
                        VStack(spacing: 6) {
                            Text("🏆").font(.system(size: 90))
                            Text(name(slot))
                                .font(.system(size: 56, weight: .heavy, design: .rounded))
                                .foregroundStyle(SlotPalette.color(for: slot))
                        }
                    }
                    if solo == nil {
                        ranking
                    }
                    voiceHint
                    buttons
                }
                .padding(24)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var title: String {
        if solo != nil { return String(localized: "Fim do treino!") }
        return result.isTie ? String(localized: "Empate!") : String(localized: "Temos um campeão!")
    }

    private func soloSummary(_ summary: SoloSummary) -> some View {
        VStack(spacing: 8) {
            Text("\(summary.score)")
                .font(.system(size: 120, weight: .black, design: .rounded))
                .foregroundStyle(Color.aganhaCream)
            Text(summary.score == 1 ? "acerto" : "acertos")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.aganhaCream.opacity(0.85))
            if summary.isRecord {
                Text("🏆 Novo recorde!").font(.title.weight(.heavy)).foregroundStyle(Color.green)
            } else {
                Text("Recorde: \(summary.best)").font(.title3).foregroundStyle(Color.aganhaCream.opacity(0.8))
            }
        }
    }

    private var ranking: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(result.ranking.enumerated()), id: \.element) { index, slot in
                HStack(spacing: 12) {
                    Text("\(index + 1)º").font(.title2.weight(.bold)).frame(width: 52, alignment: .trailing)
                    SlotChip(slot: slot, name: name(slot))
                }
                .foregroundStyle(Color.aganhaCream)
            }
        }
    }

    private var voiceHint: some View {
        VStack(spacing: 6) {
            Label(isListening ? (heard.isEmpty ? "Ouvindo…" : heard) : "Comandos de voz desligados",
                  systemImage: isListening ? "mic.fill" : "mic.slash")
                .font(.headline)
            Text("Diga \"de novo\" ou levante os dois braços para jogar outra vez. Diga \"menu\" para sair.")
                .font(.callout)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(Color.aganhaCream.opacity(0.85))
    }

    private var buttons: some View {
        HStack(spacing: 12) {
            Button("Menu", action: onMenu).buttonStyle(.bordered)
            Button(action: onPlayAgain) {
                Text(solo == nil ? "Jogar de novo" : "Treinar de novo").font(.title2.weight(.heavy)).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: "#36C9A6"))
        }
        .controlSize(.large)
        .frame(maxWidth: 520)
    }
}

/// Resultado do treino solo.
struct SoloSummary {
    let score: Int
    let best: Int
    let isRecord: Bool
}
