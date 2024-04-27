// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-rabbitmq",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(name: "RabbitMq",
            targets: ["RabbitMq"]),
    ],
    dependencies: [
        .package(url: "https://github.com/funcmike/rabbitmq-nio", from: "0.1.0-beta3")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "RabbitMq",
            dependencies: [
                .product(name: "AMQPClient", package: "rabbitmq-nio")
            ]
        ),
        .executableTarget(
            name: "Example",
            dependencies: [ "RabbitMq" ]
        )
    ]
)
