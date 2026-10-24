// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "OmniFocusMCPServer",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "omnifocus-mcp-server", targets: ["OmniFocusMCPServer"]),
    ],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.12.1"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.10.1"),
    ],
    targets: [
        .executableTarget(
            name: "OmniFocusMCPServer",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "Logging", package: "swift-log"),
            ],
            path: "Sources/OmniFocusMCPServer"
        ),
        .testTarget(
            name: "OmniFocusMCPServerTests",
            dependencies: ["OmniFocusMCPServer"],
            path: "Tests/OmniFocusMCPServerTests"
        ),
    ]
)
