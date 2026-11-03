// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AganhaTV",
    platforms: [.iOS(.v17), .macOS(.v14), .tvOS(.v17)],
    products: [.library(name: "AganhaTV", targets: ["AganhaTV"])],
    targets: [
        .target(name: "AganhaTV"),
        .testTarget(name: "AganhaTVTests", dependencies: ["AganhaTV"])
    ]
)
