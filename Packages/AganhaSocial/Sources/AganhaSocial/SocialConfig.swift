import Foundation

/// Redes onde se pode compartilhar.
public enum SocialPlatform: String, Sendable, CaseIterable {
    case tiktok, instagram, youtube, whatsapp, photos, system

    /// Esquemas de URL que o app consulta (`LSApplicationQueriesSchemes`) para saber se a rede está instalada.
    public var querySchemes: [String] {
        switch self {
        case .tiktok: ["tiktokopensdk", "tiktoksharesdk", "snssdk1180", "snssdk1233"]
        case .instagram: ["instagram-reels", "instagram-stories"]
        case .whatsapp: ["whatsapp"]
        case .youtube, .photos, .system: []
        }
    }
}

/// Chaves e interruptor das integrações. Enquanto `isLive` for falso nada é enviado: cada rede só responde "simulação".
public struct SocialConfig: Sendable, Equatable {
    /// Liga as integrações de verdade (precisa das chaves de cada rede).
    public var isLive = false
    /// TikTok for Developers: *Client Key* do app (Share Kit) e o endereço de retorno cadastrado.
    public var tiktokClientKey = ""
    public var tiktokRedirectURI = ""
    /// Meta for Developers: ID do app (Instagram Reels) — o app precisa estar "live" na Meta.
    public var metaAppID = ""
    /// Google Cloud: ID de cliente OAuth (YouTube Data API) para enviar Shorts.
    public var youtubeClientID = ""

    public init() {}

    public func isReady(_ platform: SocialPlatform) -> Bool {
        guard isLive else { return false }
        switch platform {
        case .tiktok: return !tiktokClientKey.isEmpty && !tiktokRedirectURI.isEmpty
        case .instagram: return !metaAppID.isEmpty
        case .youtube: return !youtubeClientID.isEmpty
        case .whatsapp, .photos, .system: return true
        }
    }
}
