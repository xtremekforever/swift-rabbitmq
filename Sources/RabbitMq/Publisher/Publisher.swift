import AMQPClient
import Logging
import NIOCore

/// Structure for a RabbitMq "publisher", which sends an AMQP message on an exchange.
///
/// Usage example:
/// ```swift
/// // This assumes that `basicConnection` was created previously and is connected
/// let publisher = Publisher(
///     basicConnection, "MyDemoExchange", exchangeOptions: .init(type: .fanout)
/// )
/// try await publisher.publish("Publish this!")
/// ```
public struct Publisher: Sendable {
    let channel: AMQPChannel
    let configuration: PublisherConfiguration
    let logger: Logger

    /// Create the publisher. If the default parameters are used, this publishes to the default exchange on the broker.
    ///
    /// - Parameters:
    ///   - connection: The connection for this publisher to use.
    ///   - exchangeName: The name of the exchange to publish on. This can be empty to publish on the default exchange.
    ///   - exchangeOptions: The options for declaring the exchange. This is only used if the `exchangeName` is set.
    ///   - publisherOptions: The options for publishing the message. This is always used.
    public init(
        _ connection: Connection,
        _ exchangeName: String = "",
        exchangeOptions: ExchangeOptions = ExchangeOptions(),
        publisherOptions: PublisherOptions = PublisherOptions()
    ) async throws {
        self.channel = try await connection.getChannel()
        self.configuration = PublisherConfiguration(
            exchangeName: exchangeName,
            exchangeOptions: exchangeOptions,
            publisherOptions: publisherOptions
        )
        self.logger = connection.logger

        try await channel.exchangeDeclare(configuration.exchangeName, configuration.exchangeOptions, logger)
    }

    /// Publish a message to the broker (no retries).
    ///
    /// - Parameters:
    ///   - data: The buffer of data to publish.
    ///   - routingKey: The optional routing key to use for publishing the message.
    /// - Throws: `AMQPConnectionError.connectionClosed` if the connection to the broker is not open,
    ///         or an `NIO` or `AMQPClient` error.
    public func publish(_ data: ByteBuffer, routingKey: String = "") async throws {
        _ = try await channel.publish(
            data,
            configuration.exchangeName,
            routingKey,
            configuration.publisherOptions,
            logger
        )
    }

    /// Publish a message to the broker (no retries).
    ///
    /// - Parameters:
    ///   - data: The string data of the message to publish. This string will be encoded to UTF-8 before sending.
    ///   - routingKey: The optional routing key to use for publishing the message.
    /// - Throws: `AMQPConnectionError.connectionClosed` if the connection to the broker is not open,
    ///         or an `NIO` or `AMQPClient` error.
    public func publish(_ data: String, routingKey: String = "") async throws {
        try await publish(ByteBuffer(string: data), routingKey: routingKey)
    }
}
