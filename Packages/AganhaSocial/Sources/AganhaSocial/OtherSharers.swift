import Foundation
import UIKit

/// Instagram Reels (Meta "Sharing to Reels"): põe o vídeo e o ID do app na área de transferência e abre `instagram-reels://share`.
/// Vídeo: 1080p, de 3 a 60 s, H.264/H.265/WebM, de preferência até 50 MB. O app precisa estar "live" na Meta.
@MainActor
final class InstagramReelsSharer: SocialSharer {
    func share(_ item: ShareItem, config: SocialConfig) async -> ShareOutcome {
        guard config.isReady(.instagram) else { return .notConfigured }
        guard item.kind == .video, let data = try? Data(contentsOf: item.fileURL) else { return .failed("O Reels precisa de um vídeo.") }
        guard let scheme = URL(string: "instagram-reels://share"), UIApplication.shared.canOpenURL(scheme) else { return .notInstalled }
        let items: [[String: Any]] = [["com.instagram.sharedSticker.backgroundVideo": data],
                                      ["com.instagram.sharedSticker.appID": config.metaAppID]]
        UIPasteboard.general.setItems(items, options: [.expirationDate: Date().addingTimeInterval(300)])
        return await UIApplication.shared.open(scheme) ? .shared : .failed("Não consegui abrir o Instagram.")
    }
}

/// WhatsApp: sem SDK. Para imagem/vídeo o caminho é a folha de compartilhamento do iOS; aqui só se confere se está instalado.
@MainActor
final class WhatsAppSharer: SocialSharer {
    func share(_ item: ShareItem, config: SocialConfig) async -> ShareOutcome {
        guard let scheme = URL(string: "whatsapp://"), UIApplication.shared.canOpenURL(scheme) else { return .notInstalled }
        return .notConfigured
    }
}

/// YouTube Shorts: não há SDK de compartilhar; o caminho é a YouTube Data API (`videos.insert`) com login Google, ou o usuário
/// envia pelo app do YouTube. Ainda não ligado.
@MainActor
final class YouTubeSharer: SocialSharer {
    func share(_ item: ShareItem, config: SocialConfig) async -> ShareOutcome {
        .notConfigured
    }
}
