// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DetectorTestApp",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "DetectorTestApp",
            path: "Sources"
        )
    ]
)
