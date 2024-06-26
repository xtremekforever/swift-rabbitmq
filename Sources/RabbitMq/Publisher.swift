import AMQPClient
import Logging
import NIO

public struct Publisher: Sendable {
    private let connection: Connection
    private let exchangeName: String
    private let exchangeOptions: ExchangeOptions
    private let publisherOptions: PublisherOptions
    private let logger: Logger

    public init(
        _ connection: Connection,
        _ exchangeName: String = "",
        exchangeOptions: ExchangeOptions = ExchangeOptions(),
        publisherOptions: PublisherOptions = PublisherOptions()
    ) {
        self.connection = connection
        self.exchangeName = exchangeName
        self.exchangeOptions = exchangeOptions
        self.publisherOptions = publisherOptions
        self.logger = connection.logger
    }

    public func publish(_ data: String, routingKey: String = "") async throws {
        do {
            let channel = try await connection.reuseChannel()

            // Declare exchange (only if declare = true)
            logger.trace("Declaring exchange \(exchangeName) with options: \(exchangeOptions)")
            try await channel.exchangeDeclare(exchangeName, exchangeOptions)

            // Publish the message
            logger.trace("Publishing message to exchange \(exchangeName): \(data)")
            _ = try await channel.publish(
                ByteBuffer(string: data),
                exchangeName,
                routingKey,
                publisherOptions
            )

            return
        } catch AMQPConnectionError.connectionClosed {
            logger.error("Connection closed while publishing to exchange \(exchangeName)")

            // Close connection
            try await connection.close()
        } catch {
            logger.error("Error publishing message to exchange \(exchangeName): \(error)")
        }

        // Retry again after delay
        try await Task.sleep(for: publisherOptions.retryInterval)
        try await publish(data, routingKey: routingKey)
    }
}
