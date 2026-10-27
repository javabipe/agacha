// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AganhaUI",
    platforms: [.iOS(.v17), .macOS(.v14), .tvOS(.v17)],
    products: [.library(name: "AganhaUI", targets: ["AganhaUI"])],
    dependencies: [
        .package(path: "../AganhaCore"),
        .package(path: "../AganhaVision")
    ],
    targets: [
        .target(name: "AganhaUI", dependencies: ["AganhaCore", "AganhaVision"])
    ]
)
