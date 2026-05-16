// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Fizzy",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.65.0"),
    ],
    targets: [
        .target(
            name: "FizzyKit",
            dependencies: [
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
            ],
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "Fizzy",
            dependencies: ["FizzyKit"]
        ),
        .testTarget(
            name: "FizzyTests",
            dependencies: ["FizzyKit"]
        ),
    ]
)
