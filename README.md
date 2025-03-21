# RabbitMq Library for Swift

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fxtremekforever%2Fswift-rabbitmq%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/xtremekforever/swift-rabbitmq)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fxtremekforever%2Fswift-rabbitmq%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/xtremekforever/swift-rabbitmq)

This is a high-level RabbitMQ (AMQP) library for Swift that is heavily inspired by the [go-rabbitmq](https://github.com/wagslane/go-rabbitmq) library. It uses [rabbitmq-nio](https://github.com/funcmike/rabbitmq-nio) under the hood but provides high-level abstractions to make the user experience easier, and provides functionality that most applications can use out of the box.

This library is designed to be used specifically with RabbitMQ for AMQP messaging. It is not designed to be used with any other AMQP-compatible brokers.

## Features

Some of the current features of this library include:

- **Connection Recovery** for connections to RabbitMQ.
- **High-level Publisher** for publishing messages, including declaring an exchange and publisher options.
- **High-level Consumer** for consuming messages, including declaring an exchange and queue, binding a queue to an exchange, and consumer options.
- **Retrying Publisher and Consumer** for retrying to publish or consume if RabbitMQ connection is lost or errors occur.

PLEASE NOTE: this library is still in development and has not reached v1 status yet. The API may change and new features may be added as they are needed.

In the end, the goal of this library is to provide a nice API for applications to use RabbitMQ without getting too in-the-weeds about the specifics of how to publish and consume messages from the broker.

## Installation

Add the following dependency to your Package.swift file:

```swift
.package(url: "https://github.com/xtremekforever/swift-rabbitmq", from: "0.1.0")
```

Then, add it to your target dependencies section like this:

```swift
.product(name: "RabbitMq", package: "swift-rabbitmq")
```

## Dependencies

This library only supports Swift 5.10 or later, since the underlying [Semaphore](https://github.com/groue/Semaphore) library requires at least 5.10.

Also, this library requires an accessible instance of [RabbitMQ](https://www.rabbitmq.com/) running somewhere either inside of a [Docker container](https://hub.docker.com/_/rabbitmq) or on another host.

### Compatibility

The library is only compatible with the following operating systems:

- Linux
- macOS 14 or later
- iOS 17 and later
- tvOS 17 and later
- watchOS 10 and later

## Usage

At the most basic, this library can be used as follows:

```swift
import RabbitMq

// Create connection and connect to the broker
let connection = BasicConnection("amqp://guest:guest@localhost/%2f")
try await connection.connect()

// Publish something
let publisher = Publisher(connection, "MyExchange")
try await publisher.publish("A test message")

// Consume
let consumer = Consumer(connection, "MyQueue", "MyExchange")
let stream = try await consumer.consume()
for await message in stream {
    print(message)
}

// Close the connection
await connection.close()
```

Every option that is supported by RabbitMQ can be passed to the `Publisher` and `Consumer`, so have a look at the [API documentation](https://swiftpackageindex.com/xtremekforever/swift-rabbitmq/main/documentation/rabbitmq) to see what is available.

For connection recovery patterns, separate tasks must be used since the `RetryingConnection.run()` method runs as an async task to supervise the connection. Example:

```swift
import RabbitMq

let connection = RetryingConnection("amqp://guest:guest@localhost/%2f", reconnectionInterval: .seconds(10))
let publisher = Publisher(connection, "MyExchange")
let consumer = Consumer(connection, "MyQueue", "MyExchange")

try await withThrowingDiscardingTaskGroup { group in
    // Retrying Connection
    group.addTask {
        try await connection.run()
    }

    // Retrying Publisher
    group.addTask { 
        while !Task.isCancelled {
            try await publisher.retryingPublish("Hi there!", retryInterval: .seconds(5))
            try await Task.sleep(for: .seconds(1))
        }
    }
    
    // Retrying Consumer
    group.addTask {
        let events = try await consumer.retryingConsume(retryInterval: .seconds(5))
        for await message in events {
            print(message)
        }
    }
}

// note: the `connection.run()` method will close the connection when it exits
```

For more advanced usage examples, see the example projects:

- [BasicConsumePublish](./Sources/Examples/BasicConsumePublish/): Example of publishing and consuming with no connection recovery patterns.
- [ConsumePublishServices](./Sources/Examples/ConsumePublishServices/): Example of using `swift-service-lifecycle` to connect, publish, and consume with connection recovery enabled.

## Contributions

Any updates, ideas, or proposals for the library are welcome! I have worked on this library as a personal project that can be used by all for hobby projects, work projects, or anything in between.

Open an issue or a pull request and I will be happy to review.
