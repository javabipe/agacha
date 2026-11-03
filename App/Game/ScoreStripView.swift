import AganhaCore
import SwiftUI

/// Modo pontuação no iPad: moedas de cada jogador e o que a última rodada rendeu (faixa, tempo, sequência).
struct ScoreStripView: View {
    let loop: GameLoop

    var body: some View {
        HStack(spacing: 10) {
            ForEach(loop.state.config?.slots ?? [], id: \.self) { slot in
                card(for: slot)
            }
        }
    }

    private func card(for slot: ChildSlot) -> some View {
        let player = loop.state.players[slot]
        let score = loop.lastScore(for: slot)
        return VStack(spacing: 2) {
            HStack(spacing: 6) {
                Circle().fill(SlotPalette.color(for: slot)).frame(width: 14, height: 14)
                Text(loop.name(for: slot)).font(.headline)
            }
            CoinLabel(count: player?.coins ?? 0).font(.title2.weight(.heavy))
            Text(summary(score))
                .font(.callout.weight(.semibold))
                .foregroundStyle(color(score?.tier))
                .frame(minHeight: 22)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.black.opacity(0.35), in: .rect(cornerRadius: 16))
        .foregroundStyle(.white)
    }

    private func summary(_ score: RoundScore?) -> String {
        guard let score else { return " " }
        var text = switch score.tier {
        case .perfect: String(localized: "PERFEITO")
        case .great: String(localized: "ÓTIMO")
        case .good: String(localized: "BOA")
        case .held: String(localized: "MANTEVE")
        case .miss: String(localized: "ERROU")
        }
        if score.tier != .miss { text += " +\(score.coins)" }
        if let ms = score.reactionMs { text += " · \((Double(ms) / 1000).formatted(.number.precision(.fractionLength(2)))) s" }
        if score.multiplier > 1 { text += " x\(score.multiplier)" }
        return text
    }

    private func color(_ tier: ScoreTier?) -> Color {
        switch tier {
        case .perfect: Color.aganhaYellow
        case .great: Color(hex: "#7CFFB2")
        case .good, .held: .white
        case .miss: Color(hex: "#FF8A80")
        case nil: .white
        }
    }
}
