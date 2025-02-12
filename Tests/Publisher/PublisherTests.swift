import Logging
import NIOCore
import Testing

@testable import RabbitMq

extension Publisher {
    func testConsume() async throws -> AnyAsyncSequence<String> {
        let consumer = Consumer(connection, configuration.exchangeName, configuration.exchangeName)
        return try await consumer.consume()
    }
}

@Suite(.timeLimit(.minutes(1)))
struct PublisherTests {
    let logger = createTestLogger()

    func withConnectedPublisher(
        _ exchangeName: String = "",
        body: @escaping @Sendable (Publisher) async throws -> Void
    ) async throws {
        try await withBasicConnection(logger: logger) { connection in
            let publisher = Publisher(connection, exchangeName)
            try await body(publisher)
        }
    }

    @Test
    func publishBuffer() async throws {
        try await withConnectedPublisher(#function) { publisher in
            // Arrange
            let publishBuffer = ByteBuffer(string: #function)
            let stream = try await publisher.testConsume()

            // Act
            try await publisher.publish(publishBuffer)

            // Asert
            let item = try #require(await stream.firstElement())
            #expect(ByteBuffer(string: item) == publishBuffer)
        }
    }

    @Test
    func publishString() async throws {
        try await withConnectedPublisher(#function) { publisher in
            // Arrange
            let publishString = #function
            let stream = try await publisher.testConsume()

            // Act
            try await publisher.publish(publishString)

            // Asert
            let item = try #require(await stream.firstElement())
            #expect(item == publishString)
        }
    }

    @Test
    func retryingPublishBuffer() async throws {
        try await withConnectedPublisher(#function) { publisher in
            // Arrange
            let publishBuffer = ByteBuffer(string: #function)
            let stream = try await publisher.testConsume()

            // Act
            try await publisher.retryingPublish(publishBuffer)

            // Asert
            let item = try #require(await stream.firstElement())
            #expect(ByteBuffer(string: item) == publishBuffer)
        }
    }

    @Test
    func retryingPublishString() async throws {
        try await withConnectedPublisher(#function) { publisher in
            // Arrange
            let publishString = #function
            let stream = try await publisher.testConsume()

            // Act
            try await publisher.retryingPublish(publishString)

            // Asert
            let item = try #require(await stream.firstElement())
            #expect(item == publishString)
        }
    }
}
