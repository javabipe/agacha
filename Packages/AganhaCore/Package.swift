// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AganhaCore",
    platforms: [.iOS(.v17), .macOS(.v14), .tvOS(.v17)],
    products: [.library(name: "AganhaCore", targets: ["AganhaCore"])],
    targets: [
        .target(name: "AganhaCore"),
        .testTarget(name: "AganhaCoreTests", dependencies: ["AganhaCore"])
    ]
)
