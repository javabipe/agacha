// swift-tools-version: 6.0
import PackageDescription

/// Tudo que fala com redes sociais fica neste pacote (e só aqui entram SDKs de terceiros), para dar para tirar de uma
/// versão "Kids" da App Store sem mexer no resto do app. Hoje tudo roda em modo de simulação (`SocialConfig.isLive == false`).
let package = Package(
    name: "AganhaSocial",
    platforms: [.iOS(.v17)],
    products: [.library(name: "AganhaSocial", targets: ["AganhaSocial"])],
    dependencies: [
        .package(url: "https://github.com/tiktok/tiktok-opensdk-ios.git", from: "2.5.0")
    ],
    targets: [
        .target(
            name: "AganhaSocial",
            dependencies: [
                .product(name: "TikTokOpenSDKCore", package: "tiktok-opensdk-ios"),
                .product(name: "TikTokOpenShareSDK", package: "tiktok-opensdk-ios")
            ]
        ),
        .testTarget(name: "AganhaSocialTests", dependencies: ["AganhaSocial"])
    ]
)
