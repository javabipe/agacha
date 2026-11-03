import Foundation

/// O que se compartilha: um vídeo ou uma imagem (hoje, o pôster/foto do momento) e a legenda.
public struct ShareItem: Sendable {
    public enum Kind: Sendable { case image, video }

    public let fileURL: URL
    public let kind: Kind
    public let caption: String
    /// Identificador do item na fototeca (o Share Kit do TikTok exige que o arquivo esteja lá).
    public let photoLibraryID: String?

    public init(fileURL: URL, kind: Kind, caption: String, photoLibraryID: String? = nil) {
        self.fileURL = fileURL
        self.kind = kind
        self.caption = caption
        self.photoLibraryID = photoLibraryID
    }
}

public enum ShareOutcome: Sendable, Equatable {
    case shared
    /// A rede ainda não foi ligada (sem chaves ou `isLive` falso): é só simulação.
    case notConfigured
    case notInstalled
    case cancelled
    case failed(String)
}

public protocol SocialSharer: Sendable {
    @MainActor func share(_ item: ShareItem, config: SocialConfig) async -> ShareOutcome
}

/// Escolhe quem envia para cada rede. Sem configuração ligada, nenhuma integração toca em rede nenhuma.
@MainActor
public final class SocialShareCenter {
    public static let shared = SocialShareCenter()

    public var config = SocialConfig()
    private let sharers: [SocialPlatform: any SocialSharer]

    public init(sharers: [SocialPlatform: any SocialSharer]? = nil) {
        self.sharers = sharers ?? [
            .tiktok: TikTokSharer(),
            .instagram: InstagramReelsSharer(),
            .whatsapp: WhatsAppSharer(),
            .youtube: YouTubeSharer()
        ]
    }

    public func share(_ item: ShareItem, to platform: SocialPlatform) async -> ShareOutcome {
        guard config.isReady(platform), let sharer = sharers[platform] else { return .notConfigured }
        return await sharer.share(item, config: config)
    }
}
