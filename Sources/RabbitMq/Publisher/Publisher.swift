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
    let connection: Connection
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
    ) {
        self.connection = connection
        self.configuration = PublisherConfiguration(
            exchangeName: exchangeName,
            exchangeOptions: exchangeOptions,
            publisherOptions: publisherOptions
        )
        self.logger = connection.logger.withMetadata(["exchangeName": .string(configuration.exchangeName)])
    }

    /// Publish a message to the broker (no retries).
    ///
    /// - Parameters:
    ///   - data: The buffer of data to publish.
    ///   - routingKey: The optional routing key to use for publishing the message.
    /// - Throws: `AMQPConnectionError.connectionClosed` if the connection to the broker is not open,
    ///         or an `NIO` or `AMQPClient` error.
    /// - Returns: `AMQPResponse.Channel.Basic.Published` with information about the published message.
    @discardableResult public func publish(
        _ data: ByteBuffer, routingKey: String = ""
    ) async throws -> AMQPResponse.Channel.Basic.Published {
        let response = try await connection.performPublish(configuration, data, routingKey: routingKey)
        logger.trace("Published message", metadata: ["response": .string("\(response)")])
        return response
    }

    /// Publish a message to the broker (no retries).
    ///
    /// - Parameters:
    ///   - data: The string data of the message to publish. This string will be encoded to UTF-8 before sending.
    ///   - routingKey: The optional routing key to use for publishing the message.
    /// - Throws: `AMQPConnectionError.connectionClosed` if the connection to the broker is not open,
    ///         or an `NIO` or `AMQPClient` error.
    /// - Returns: `AMQPResponse.Channel.Basic.Published` with information about the published message.
    @discardableResult public func publish(
        _ data: String, routingKey: String = ""
    ) async throws -> AMQPResponse.Channel.Basic.Published {
        return try await publish(ByteBuffer(string: data), routingKey: routingKey)
    }

    /// Publish a message to the broker with retries.
    ///
    /// This method will not return until it is cancelled or is able to publish the message.
    /// It performs a publish operation but will retry indefinitely until it is able to
    /// publish the message to the broker.
    ///
    /// - Parameters:
    ///   - data: The NIO `ByteBuffer` data of the message to publish. This can be JSON, XML, or binary data.
    ///   - routingKey: The optional routing key to use for publishing the message.
    ///   - retryInterval: The interval at which to retry publishing the message.
    /// - Throws: `AMQPConnectionError.connectionClosed` if the connection to the broker is not open,
    ///         or an `NIO` or `AMQPClient` error.
    /// - Returns: `AMQPResponse.Channel.Basic.Published` if the message was published.
    @discardableResult public func retryingPublish(
        _ data: ByteBuffer, routingKey: String = "", retryInterval: Duration = defaultRetryInterval
    ) async throws -> AMQPResponse.Channel.Basic.Published? {
        return try await RetryingPublisher(connection, configuration, retryInterval).publish(
            data, routingKey: routingKey
        )
    }

    /// Publish a message to the broker with retries.
    ///
    /// This method will not return until it is cancelled or is able to publish the message.
    /// It performs a publish operation but will retry indefinitely until it is able to
    /// publish the message to the broker.
    ///
    /// - Parameters:
    ///   - data: The string data of the message to publish. This string will be encoded to UTF-8 before sending.
    ///   - routingKey: The optional routing key to use for publishing the message.
    ///   - retryInterval: The interval at which to retry publishing the message.
    /// - Throws: `AMQPConnectionError.connectionClosed` if the connection to the broker is not open,
    ///         or an `NIO` or `AMQPClient` error.
    /// - Returns: `AMQPResponse.Channel.Basic.Published` if the message was published.
    @discardableResult public func retryingPublish(
        _ data: String, routingKey: String = "", retryInterval: Duration = defaultRetryInterval
    ) async throws -> AMQPResponse.Channel.Basic.Published? {
        return try await retryingPublish(ByteBuffer(string: data), routingKey: routingKey, retryInterval: retryInterval)
    }
}
