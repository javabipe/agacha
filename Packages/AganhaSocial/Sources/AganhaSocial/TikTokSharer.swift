import Foundation
import TikTokOpenShareSDK

/// TikTok Share Kit: abre o TikTok com o vídeo/imagem que já está na fototeca. Só funciona com a *Client Key* cadastrada
/// (e `TikTokClientKey`/esquemas no Info.plist). Sem isso responde `notConfigured` e não chama o SDK.
@MainActor
final class TikTokSharer: SocialSharer {
    /// O SDK só devolve a resposta enquanto o app guarda a requisição.
    private var pending: TikTokShareRequest?

    func share(_ item: ShareItem, config: SocialConfig) async -> ShareOutcome {
        guard config.isReady(.tiktok) else { return .notConfigured }
        guard let identifier = item.photoLibraryID else { return .failed("O arquivo precisa estar na fototeca para o TikTok.") }
        let request = TikTokShareRequest(localIdentifiers: [identifier], mediaType: item.kind == .video ? .video : .image,
                                         redirectURI: config.tiktokRedirectURI)
        pending = request
        let outcome: ShareOutcome = await withCheckedContinuation { continuation in
            request.send { response in
                guard let response = response as? TikTokShareResponse else {
                    continuation.resume(returning: .failed("Resposta inesperada do TikTok."))
                    return
                }
                let failure = response.errorDescription ?? "Erro do TikTok."
                continuation.resume(returning: response.errorCode == .noError ? .shared : .failed(failure))
            }
        }
        pending = nil
        return outcome
    }
}
