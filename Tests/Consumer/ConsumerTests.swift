import Logging
import NIOCore
import Testing

@testable import RabbitMq

extension Consumer {
    func testPublish(_ data: String) async throws {
        let publisher = Publisher(connection, configuration.exchangeName)
        try await publisher.publish(data)
    }
}

@Suite(.timeLimit(.minutes(1)))
struct ConsumerTests {
    let logger = createTestLogger()

    func withConnectedConsumer(
        _ consumerName: String = "",
        body: @escaping @Sendable (Consumer) async throws -> Void
    ) async throws {
        try await withBasicConnection(logger: logger) { connection in
            let consumer = Consumer(connection, consumerName, consumerName, consumerOptions: .init(autoAck: true))
            try await body(consumer)
        }
    }

    @Test
    func consume() async throws {
        // Arrange
        try await withConnectedConsumer(#function) { consumer in
            let publishString = "A test string"
            let stream = try await consumer.consume()

            // Act
            try await consumer.testPublish(publishString)

            // Assert
            let item = try #require(await stream.firstElement())
            #expect(item == publishString)
        }
    }

    @Test
    func consumeBuffer() async throws {
        // Arrange
        try await withConnectedConsumer(#function) { consumer in
            let publishString = "A test string"
            let stream = try await consumer.consumeBuffer()

            // Act
            try await consumer.testPublish(publishString)

            // Assert
            let item = try #require(await stream.firstElement())
            #expect(item == ByteBuffer(string: publishString))
        }
    }

    @Test
    func consumeDelivery() async throws {
        // Arrange
        try await withConnectedConsumer(#function) { consumer in
            let publishString = "A test string"
            let stream = try await consumer.consumeDelivery()

            // Act
            try await consumer.testPublish(publishString)

            // Assert
            let item = try #require(await stream.firstElement())
            #expect(item.body == ByteBuffer(string: publishString))
        }
    }

    @Test
    func retryingConsume() async throws {
        // Arrange
        try await withConnectedConsumer(#function) { consumer in
            let publishString = "A test string"
            let stream = try await consumer.retryingConsume()

            // Act
            try await consumer.testPublish(publishString)

            // Assert
            let item = try #require(await stream.firstElement())
            #expect(item == publishString)
        }
    }

    @Test
    func retryingConsumeBuffer() async throws {
        // Arrange
        try await withConnectedConsumer(#function) { consumer in
            let publishString = "A test string"
            let stream = try await consumer.retryingConsumeBuffer()

            // Act
            try await consumer.testPublish(publishString)

            // Assert
            let item = try #require(await stream.firstElement())
            #expect(item == ByteBuffer(string: publishString))
        }
    }

    @Test
    func retryingConsumeDelivery() async throws {
        // Arrange
        try await withConnectedConsumer(#function) { consumer in
            let publishString = "A test string"
            let stream = try await consumer.retryingConsumeDelivery()

            // Act
            try await consumer.testPublish(publishString)

            // Assert
            let item = try #require(await stream.firstElement())
            #expect(item.body == ByteBuffer(string: publishString))
        }
    }
}
