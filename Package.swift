// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "KiroBar",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "KiroBarCore",
            path: "Sources/KiroBarCore"
        ),
        .executableTarget(
            name: "KiroBar",
            dependencies: ["KiroBarCore"],
            path: "Sources/KiroBar",
            resources: [.process("kiro-icon.png")]
        ),
        .executableTarget(
            name: "KiroBarTests",
            dependencies: ["KiroBarCore"],
            path: "Tests/KiroBarTests"
        )
    ]
)
