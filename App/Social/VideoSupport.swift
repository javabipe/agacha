import AVFoundation
import AVKit
import SwiftUI
import UIKit

/// Um quadro do vídeo (perto do fim, com a dancinha) para usar de capa nos cartões e na folha de compartilhar.
enum VideoThumbnail {
    nonisolated(unsafe) private static let cache = NSCache<NSURL, UIImage>()

    /// `fraction`: onde pegar o quadro (1 = fim). Sem ele, 1,2 s antes do fim (a dancinha no vídeo de avatares).
    static func image(for url: URL, fraction: Double? = nil) async -> UIImage? {
        if let cached = cache.object(forKey: url as NSURL) { return cached }
        let asset = AVURLAsset(url: url)
        guard let duration = try? await asset.load(.duration), duration.seconds > 0 else { return nil }
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 540, height: 960)
        let seconds = fraction.map { duration.seconds * $0 } ?? max(0, duration.seconds - 1.2)
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        guard let cgImage = try? await generator.image(at: time).image else { return nil }
        let image = UIImage(cgImage: cgImage)
        cache.setObject(image, forKey: url as NSURL)
        return image
    }
}

/// Tocar o vídeo do momento em tela cheia.
struct VideoPlayerSheet: View {
    let url: URL
    let onClose: () -> Void
    @State private var player: AVPlayer?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            if let player { VideoPlayer(player: player).ignoresSafeArea() }
            Button("Fechar", action: onClose).buttonStyle(.borderedProminent).tint(.black.opacity(0.6)).padding()
        }
        .onAppear {
            let player = AVPlayer(url: url)
            self.player = player
            player.play()
        }
        .onDisappear { player?.pause() }
    }
}

/// Capa de vídeo: a imagem com o botão de tocar por cima.
struct VideoCover: View {
    let image: UIImage
    let duration: String?

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .clipShape(.rect(cornerRadius: 22))
            .overlay {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(.white.opacity(0.92))
                    .shadow(radius: 6)
            }
            .overlay(alignment: .topTrailing) {
                if let duration {
                    Text(duration).font(.caption.weight(.bold)).padding(6).background(.black.opacity(0.55), in: .capsule).padding(8)
                }
            }
    }
}
