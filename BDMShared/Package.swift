// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "BDMShared",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "BDMShared", targets: ["BDMShared"]),
    ],
    targets: [
        .target(name: "BDMShared"),
    ]
)
