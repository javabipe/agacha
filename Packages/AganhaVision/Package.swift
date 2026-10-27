// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AganhaVision",
    platforms: [.iOS(.v17), .macOS(.v14), .tvOS(.v17)],
    products: [.library(name: "AganhaVision", targets: ["AganhaVision"])],
    dependencies: [.package(path: "../AganhaCore")],
    targets: [
        .target(name: "AganhaVision", dependencies: ["AganhaCore"]),
        .testTarget(name: "AganhaVisionTests", dependencies: ["AganhaVision"])
    ]
)
