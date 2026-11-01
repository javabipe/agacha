import AganhaCore
import SwiftUI

struct GameOverView: View {
    let result: GameResult
    let onPlayAgain: () -> Void
    let onMenu: () -> Void

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    Text(result.isTie ? "Empate!" : "Temos um campeão!")
                        .font(.system(size: 52, weight: .black, design: .rounded))
                        .foregroundStyle(Color.aganhaYellow)
                    ForEach(result.winners, id: \.self) { slot in
                        VStack(spacing: 6) {
                            Text("🏆").font(.system(size: 90))
                            Text(SlotColors.displayName(slot))
                                .font(.system(size: 56, weight: .heavy, design: .rounded))
                                .foregroundStyle(SlotPalette.color(for: slot))
                        }
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(result.ranking.enumerated()), id: \.element) { index, slot in
                            HStack(spacing: 12) {
                                Text("\(index + 1)º").font(.title2.weight(.bold)).frame(width: 52, alignment: .trailing)
                                SlotChip(slot: slot)
                            }
                            .foregroundStyle(Color.aganhaCream)
                        }
                    }
                    HStack(spacing: 12) {
                        Button("Menu", action: onMenu).buttonStyle(.bordered)
                        Button(action: onPlayAgain) {
                            Text("Jogar de novo").font(.title2.weight(.heavy)).frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(hex: "#36C9A6"))
                    }
                    .controlSize(.large)
                    .frame(maxWidth: 520)
                }
                .padding(24)
                .frame(maxWidth: .infinity)
            }
        }
    }
}
