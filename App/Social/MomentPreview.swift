import AganhaCore
import SwiftUI
import UIKit

/// Prévia vertical (9:16) do vídeo que seria compartilhado: avatares dançando e chorando, placar e a marca do jogo.
/// Não mostra nenhuma imagem real das crianças: só os avatares, desenhados a partir do movimento.
struct MomentPreview: View {
    let moment: Moment
    var showsOverlay = true
    /// Foto real ("shot") no lugar dos avatares.
    var photo: UIImage?
    /// Congela os avatares num instante (para gerar a imagem do pôster).
    var frozenAt: Double?

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "#3A2A6B"), Color(hex: "#1B1433")], startPoint: .top, endPoint: .bottom)
            if let photo {
                photoLayer(photo)
            } else {
                AvatarStage(figures: { time, aspect in figures(time: time, aspect: aspect) }, frozenAt: frozenAt)
            }
            if showsOverlay { MomentOverlay(moment: moment) }
        }
        .aspectRatio(9 / 16, contentMode: .fit)
        .clipShape(.rect(cornerRadius: 22))
        .overlay { RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.25), lineWidth: 1.5) }
    }

    /// A foto inteira no meio, com uma cópia borrada preenchendo o fundo (assim ninguém sai cortado).
    private func photoLayer(_ photo: UIImage) -> some View {
        ZStack {
            Color.clear
                .overlay { Image(uiImage: photo).resizable().scaledToFill() }
                .clipped()
                .blur(radius: 24)
                .overlay { Color.black.opacity(0.35) }
            Image(uiImage: photo).resizable().scaledToFit()
            LinearGradient(colors: [.black.opacity(0.55), .clear, .clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom)
        }
    }

    private func figures(time: Double, aspect: Double) -> [AvatarFigure] {
        let players = moment.players, count = players.count
        let scale = count <= 1 ? 0.85 : (count == 2 ? 0.7 : (count == 3 ? 0.56 : 0.45))
        return players.enumerated().map { index, player in
            let x = count == 1 ? 0.5 : 0.17 + 0.66 * Double(index) / Double(count - 1)
            let spec = player.isWinner ? AvatarPoses.dance(time + Double(index) * 0.1) : AvatarPoses.sad(time + Double(index) * 0.25)
            return AvatarFigure.player(name: nil, colorHex: player.colorHex, x: x, spec: spec, mood: player.isWinner ? .win : .sad,
                                       crown: player.isWinner, look: player.isGirl ? .girl : .boy, aspect: aspect, scale: scale,
                                       floor: showsOverlay ? 0.6 : 0.8)
        }
    }
}

/// Título, número de rodadas e placar sobre o vídeo/pôster (o mesmo no vídeo de avatares).
struct MomentOverlay: View {
    let moment: Moment

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Aganha!").font(.system(size: 22, weight: .black, design: .rounded)).foregroundStyle(Color.aganhaYellow)
                Spacer()
                Text("\(moment.rounds) rodadas").font(.caption.weight(.bold)).foregroundStyle(.white.opacity(0.8))
            }
            Text(moment.headline)
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .shadow(radius: 4)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Spacer()
            scoreboard
        }
        .padding(12)
    }

    private var scoreboard: some View {
        VStack(spacing: 4) {
            ForEach(moment.players.sorted { $0.coins > $1.coins }) { player in
                HStack(spacing: 6) {
                    Circle().fill(Color(hex: player.colorHex)).frame(width: 12, height: 12)
                    Text(player.name).font(.caption.weight(.bold))
                    Spacer()
                    if moment.mode == .score { CoinLabel(count: player.coins).font(.caption.weight(.heavy)) }
                    if player.isWinner { Text("👑") }
                }
                .foregroundStyle(.white)
            }
            if let fastest = moment.fastestMs {
                Text("Mais rápido: \((Double(fastest) / 1000).formatted(.number.precision(.fractionLength(2)))) s")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.aganhaCream.opacity(0.85))
            }
        }
        .padding(10)
        .background(.black.opacity(0.45), in: .rect(cornerRadius: 14))
    }
}
