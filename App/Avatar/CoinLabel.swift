import SwiftUI

/// Moeda dourada desenhada (o emoji de moeda aparece cinza em alguns aparelhos) seguida da quantidade.
struct CoinLabel: View {
    let count: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "bitcoinsign.circle.fill").foregroundStyle(Color(hex: "#FFC83D"))
            Text("\(count)")
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(count) moedas")
    }
}
