// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VibeUsage",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "VibeUsage",
            dependencies: [],
            path: "VibeUsage",
            exclude: ["Info.plist"],
            resources: [
                .process("Resources/menubar-icon.png"),
                .process("Resources/claude-icon.png"),
                .process("Resources/codex-icon.png"),
                .process("Resources/AppIcon.icon"),
                .process("Resources/Assets.xcassets"),
                .copy("Resources/vibe-usage-cli")
            ]
        ),
        .testTarget(
            name: "VibeUsageTests",
            dependencies: ["VibeUsage"]
        )
    ]
)
