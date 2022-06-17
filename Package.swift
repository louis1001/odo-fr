// swift-tools-version: 5.6
import PackageDescription

let package = Package(
    name: "odo",
    dependencies: [
        .package(url: "https://github.com/andybest/linenoise-swift", from: "0.0.3"),
    ],
    targets: [
        .target(name: "odolib", dependencies: [], path: "Sources/odo/"),
        .executableTarget(name: "odo_repl", dependencies: [
            .product(name: "LineNoise", package: "linenoise-swift"),
            "odolib"
        ])
    ])
