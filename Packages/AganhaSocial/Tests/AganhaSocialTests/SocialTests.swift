@testable import AganhaSocial
import Foundation
import Testing

@MainActor
@Suite struct SocialTests {
    private let item = ShareItem(fileURL: URL(fileURLWithPath: "/tmp/x.mp4"), kind: .video, caption: "oi")

    @Test func nothingIsReadyUntilLiveWithKeys() {
        var config = SocialConfig()
        for platform in SocialPlatform.allCases { #expect(!config.isReady(platform)) }
        config.isLive = true
        #expect(!config.isReady(.tiktok) && !config.isReady(.instagram) && !config.isReady(.youtube))
        config.tiktokClientKey = "k"
        #expect(!config.isReady(.tiktok))
        config.tiktokRedirectURI = "https://example.com/r"
        #expect(config.isReady(.tiktok))
        config.metaAppID = "123"
        #expect(config.isReady(.instagram))
    }

    @Test func defaultCenterIsOnlyASimulation() async {
        let center = SocialShareCenter()
        for platform in SocialPlatform.allCases {
            #expect(await center.share(item, to: platform) == .notConfigured)
        }
    }

    @Test func aReadyPlatformCallsItsSharer() async {
        struct Recorder: SocialSharer {
            func share(_ item: ShareItem, config: SocialConfig) async -> ShareOutcome { .shared }
        }
        let center = SocialShareCenter(sharers: [.whatsapp: Recorder()])
        #expect(await center.share(item, to: .whatsapp) == .notConfigured)   // isLive ainda falso
        center.config.isLive = true
        #expect(await center.share(item, to: .whatsapp) == .shared)
    }

    @Test func eachNetworkDeclaresItsQuerySchemes() {
        #expect(SocialPlatform.instagram.querySchemes.contains("instagram-reels"))
        #expect(SocialPlatform.tiktok.querySchemes.contains("tiktoksharesdk"))
    }
}
