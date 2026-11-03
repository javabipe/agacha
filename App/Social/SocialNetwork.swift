import AganhaSocial
import SwiftUI

/// Destinos de compartilhamento. `integration` resume como cada um será ligado de verdade (ver docs/SOCIAL.md).
enum SocialNetwork: String, CaseIterable, Identifiable {
    case tiktok, instagram, youtube, whatsapp, photos, more

    var id: String { rawValue }

    var platform: SocialPlatform {
        switch self {
        case .tiktok: .tiktok
        case .instagram: .instagram
        case .youtube: .youtube
        case .whatsapp: .whatsapp
        case .photos: .photos
        case .more: .system
        }
    }

    var title: String {
        switch self {
        case .tiktok: "TikTok"
        case .instagram: "Instagram Reels"
        case .youtube: "YouTube Shorts"
        case .whatsapp: "WhatsApp"
        case .photos: String(localized: "Salvar no álbum")
        case .more: String(localized: "Mais…")
        }
    }

    var symbol: String {
        switch self {
        case .tiktok: "music.note"
        case .instagram: "camera.fill"
        case .youtube: "play.rectangle.fill"
        case .whatsapp: "message.fill"
        case .photos: "square.and.arrow.down"
        case .more: "square.and.arrow.up"
        }
    }

    var gradient: [Color] {
        switch self {
        case .tiktok: [Color(hex: "#25F4EE"), Color(hex: "#FE2C55")]
        case .instagram: [Color(hex: "#F58529"), Color(hex: "#DD2A7B"), Color(hex: "#8134AF")]
        case .youtube: [Color(hex: "#FF0000"), Color(hex: "#B00000")]
        case .whatsapp: [Color(hex: "#25D366"), Color(hex: "#128C7E")]
        case .photos: [Color(hex: "#4D9DE0"), Color(hex: "#3A6FB5")]
        case .more: [Color(hex: "#8E7BFF"), Color(hex: "#5B47C8")]
        }
    }

    /// Texto curto do que a integração de verdade vai fazer (mostrado como "em breve" na simulação).
    var integration: String {
        switch self {
        case .tiktok: String(localized: "Abre o editor do TikTok com o vídeo (Share Kit).")
        case .instagram: String(localized: "Abre o Reels do Instagram com o vídeo pronto.")
        case .youtube: String(localized: "Envia o vídeo vertical como Short.")
        case .whatsapp: String(localized: "Manda o vídeo para uma conversa ou grupo.")
        case .photos: String(localized: "Guarda o vídeo no álbum do aparelho.")
        case .more: String(localized: "Abre a folha de compartilhamento do iOS.")
        }
    }
}
