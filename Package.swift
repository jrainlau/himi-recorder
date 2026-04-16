// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HimiRecorder",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "HimiRecorder",
            path: "HimiRecorder",
            exclude: [
                "Info.plist",
                "HimiRecorder.entitlements",
            ],
            sources: [
                "App",
                "Protocols",
                "Controllers",
                "Views",
                "Core",
                "Managers",
                "Utils",
            ],
            resources: [
                .process("Assets.xcassets"),
            ]
        ),
        .testTarget(
            name: "HimiRecorderTests",
            dependencies: ["HimiRecorder"],
            path: "HimiRecorderTests"
        ),
    ]
)
