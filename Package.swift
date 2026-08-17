// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Port",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Port",
            path: "Sources/Port"
        )
    ]
)
