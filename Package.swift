// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

var targets: [Target] = [
    .target(
        name: "RabbitMq",
        dependencies: [
            .product(name: "AMQPClient", package: "rabbitmq-nio"),
            .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
            .product(name: "Logging", package: "swift-log"),
            .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
            .product(name: "Semaphore", package: "semaphore"),
        ]
    ),
    .executableTarget(
        name: "BasicConsumePublish",
        dependencies: [
            "RabbitMq",
            .product(name: "ArgumentParser", package: "swift-argument-parser"),
        ],
        path: "Sources/Examples/BasicConsumePublish"
    ),
    .executableTarget(
        name: "ConsumePublishServices",
        dependencies: [
            "RabbitMq",
            .product(name: "ArgumentParser", package: "swift-argument-parser"),
        ],
        path: "Sources/Examples/ConsumePublishServices"
    ),
]

// Enable strict concurrency checking for all targets
for target in targets {
    var settings: [SwiftSetting] = target.swiftSettings ?? []
    settings.append(.enableExperimentalFeature("StrictConcurrency"))
    target.swiftSettings = settings
}

#if canImport(Testing)
    targets.append(
        .testTarget(
            name: "Tests",
            dependencies: [
                "RabbitMq",
                .product(name: "Testcontainers", package: "testcontainers-swift"),
            ]
        )
    )
#endif

let package = Package(
    name: "swift-rabbitmq",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .tvOS(.v17),
        .watchOS(.v10),
    ],
    products: [
        .library(name: "RabbitMq", targets: ["RabbitMq"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.1.0"),
        .package(url: "https://github.com/funcmike/rabbitmq-nio", from: "0.1.0-beta4"),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-log", from: "1.0.0"),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "2.0.0"),
        .package(url: "https://github.com/groue/Semaphore.git", from: "0.1.0"),
        .package(url: "https://github.com/xtremekforever/testcontainers-swift.git", branch: "main"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.0.0"),
    ],
    targets: targets
)
