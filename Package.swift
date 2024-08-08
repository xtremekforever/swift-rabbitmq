// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-rabbitmq",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "RabbitMq",
            targets: ["RabbitMq"])
    ],
    dependencies: [
        .package(url: "https://github.com/funcmike/rabbitmq-nio", branch: "main"),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-log", from: "1.0.0"),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "2.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "RabbitMq",
            dependencies: [
                .product(name: "AMQPClient", package: "rabbitmq-nio"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
            ]
        ),
        .executableTarget(
            name: "BasicConsumePublish",
            dependencies: ["RabbitMq"],
            path: "Sources/Examples/BasicConsumePublish"
        ),
        .executableTarget(
            name: "ConsumePublishServices",
            dependencies: [
                "RabbitMq"
            ],
            path: "Sources/Examples/ConsumePublishServices"
        ),
    ]
)

// Enable strict concurrency checking for all targets
for target in package.targets {
    var settings = target.swiftSettings ?? []
    settings.append(.enableExperimentalFeature("StrictConcurrency"))
    target.swiftSettings = settings
}
