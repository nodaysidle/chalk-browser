// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "nodaysidle",
    platforms: [
        .macOS(.v14),
    ],
    targets: [
        .executableTarget(
            name: "nodaysidle",
            path: "Sources/nodaysidle"
        ),
        .testTarget(
            name: "nodaysidleTests",
            dependencies: ["nodaysidle"],
            path: "Tests/nodaysidleTests"
        ),
    ]
)
