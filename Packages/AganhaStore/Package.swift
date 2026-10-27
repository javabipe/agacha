// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AganhaStore",
    platforms: [.iOS(.v17), .macOS(.v14), .tvOS(.v17)],
    products: [.library(name: "AganhaStore", targets: ["AganhaStore"])],
    targets: [.target(name: "AganhaStore")]
)
