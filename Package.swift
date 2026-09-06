// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ProjectHub",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "ProjectHub",
            path: "Sources/ProjectHub",
            resources: [.process("Resources")],
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .testTarget(
            name: "ProjectHubTests",
            dependencies: ["ProjectHub"],
            path: "Tests/ProjectHubTests"
        )
    ]
)
