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
            guard let channel = try await connection.getChannel() else {
                throw AMQPConnectionError.connectionClosed(replyCode: nil, replyText: nil)
            }

            // Declare exchange (only if declare = true)
            try await channel.exchangeDeclare(exchangeName, exchangeOptions, logger)

            // Publish the message
            _ = try await channel.publish(
                ByteBuffer(string: data),
                exchangeName,
                routingKey,
                publisherOptions,
                logger
            )

        } catch AMQPConnectionError.connectionClosed(let replyCode, let replyText) {
            let error = AMQPConnectionError.connectionClosed(replyCode: replyCode, replyText: replyText)
            logger.error("Connection closed while publishing from exchange \(exchangeName): \(error)")

            // Wait for connection again (retry interval does not factor in when waiting for reconnection)
            if publisherOptions.retryInterval != nil {
                try await connection.waitForConnection()
                return try await publish(data, routingKey: routingKey)
            }

            // Otherwise rethrow error
            throw error
        } catch {
            logger.error("Error publishing message to exchange \(exchangeName): \(error)")

            // Publish retry (if enabled)
            if let retryInterval = publisherOptions.retryInterval {
                logger.debug("Will retry publishing to exchange \(exchangeName) in \(retryInterval)")
                try await Task.sleep(for: retryInterval)
                try await publish(data, routingKey: routingKey)
            }

            // Rethrow error if we are not retrying publish
            throw error
        }
    }
}
