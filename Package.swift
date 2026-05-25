// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DistillMCP",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "DistillMCP", targets: ["DistillMCP"])
    ],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.10.0")
    ],
    targets: [
        .executableTarget(
            name: "DistillMCP",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk")
            ],
            path: "Sources/DistillMCP"
        )
    ]
)
