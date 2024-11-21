import AMQPClient
import Logging
import NIOCore

public actor RetryingPublisher: Sendable {
    let connection: Connection
    let configuration: PublisherConfiguration
    let logger: Logger
    let retryInterval: Duration

    var publisher: Publisher? = nil

    public init(
        _ connection: Connection,
        _ exchangeName: String = "",
        exchangeOptions: ExchangeOptions = ExchangeOptions(),
        publisherOptions: PublisherOptions = PublisherOptions(),
        retryInterval: Duration
    ) {
        self.connection = connection
        self.configuration = PublisherConfiguration(
            exchangeName: exchangeName,
            exchangeOptions: exchangeOptions,
            publisherOptions: publisherOptions
        )
        self.logger = connection.logger
        self.retryInterval = retryInterval
    }

    public func publish(_ data: ByteBuffer, routingKey: String = "") async throws {
        while !Task.isCancelledOrShuttingDown {
            do {
                if publisher == nil {
                    publisher = try await Publisher(
                        connection, configuration.exchangeName,
                        exchangeOptions: configuration.exchangeOptions,
                        publisherOptions: configuration.publisherOptions
                    )
                }

                try await connection.performPublish(configuration, data, routingKey: routingKey)
                break
            } catch AMQPConnectionError.connectionClosed(let replyCode, let replyText) {
                if publisher == nil {
                    let error = AMQPConnectionError.connectionClosed(replyCode: replyCode, replyText: replyText)
                    logger.error(
                        "Connection closed while publishing to exchange \(configuration.exchangeName): \(error)")
                }

                publisher = nil

                // Wait for connection, timeout after retryInterval
                await self.connection.waitForConnection(timeout: retryInterval)
            } catch {
                logger.error("Error publishing message to exchange \(configuration.exchangeName): \(error)")

                // Publish retry (if enabled)
                logger.debug("Will retry publishing to exchange \(configuration.exchangeName) in \(retryInterval)")
                try await Task.sleep(for: retryInterval)
            }
        }
    }

    public func publish(_ data: String, routingKey: String = "") async throws {
        try await publish(ByteBuffer(string: data), routingKey: routingKey)
    }
}
