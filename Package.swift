// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "KiroBar",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "KiroBar",
            path: "Sources/KiroBar",
            resources: [.process("kiro-icon.png")]
        )
    ]
)
