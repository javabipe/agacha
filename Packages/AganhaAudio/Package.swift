// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AganhaAudio",
    platforms: [.iOS(.v17), .macOS(.v14), .tvOS(.v17)],
    products: [.library(name: "AganhaAudio", targets: ["AganhaAudio"])],
    targets: [.target(name: "AganhaAudio")]
)
