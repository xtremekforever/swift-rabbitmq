@preconcurrency import AMQPClient
import AsyncAlgorithms
import Logging
import NIO

/// Structure for a RabbitMq "consumer", which consumes AMQP messages from a queue.
///
/// Usage example:
/// ```swift
/// // This assumes that `basicConnection` was created previously and is connected
/// let consumer = Consumer(
///     basicConnection, "MyDemoQueue", "MyDemoExchange", exchangeOptions: .init(type: .fanout)
/// )
/// let stream = try await consumer.consume()
/// for await message in stream {
///     print(message)
/// }
/// ```
public struct Consumer: Sendable {
    let connection: Connection
    let configuration: ConsumerConfiguration
    let logger: Logger

    /// Create the consumer. If the default parameters are used, this consumes on the default queue on the broker.
    ///
    /// - Parameters:
    ///   - connection: The connection for this consumer to use.
    ///   - queueName: The name of the queue to consume from. This can be empty to consume on the default queue.
    ///   - exchangeName: The name of the exchange to declare and bind the queue to. This can be empty to not bind an exchange to the queue.
    ///   - routingKey: Optional routing key to use for this consumer.
    ///   - exchangeOptions: The options for declaring the exchange. This is only used if the `exchangeName` is set.
    ///   - queueOptions: The options for declaring the queue. This is only used if the 'queueName' is set.
    ///   - bindingOptions: The options for binding the queue to the exchange. This is only used if both `queueName` and `exchangeName` are set.
    ///   - consumerOptions: The options for the consumer. This can be used to pass additional arguments to the consumer.
    public init(
        _ connection: Connection,
        _ queueName: String,
        _ exchangeName: String = "",
        _ routingKey: String = "",
        exchangeOptions: ExchangeOptions = ExchangeOptions(),
        queueOptions: QueueOptions = QueueOptions(),
        bindingOptions: BindingOptions = BindingOptions(),
        consumerOptions: ConsumerOptions = ConsumerOptions()
    ) {
        self.connection = connection
        self.configuration = ConsumerConfiguration(
            queueName: queueName,
            exchangeName: exchangeName,
            routingKey: routingKey,
            exchangeOptions: exchangeOptions,
            queueOptions: queueOptions,
            bindingOptions: bindingOptions,
            consumerOptions: consumerOptions
        )
        self.logger = connection.logger
    }

    /// Start consuming from the consumer (no retries).
    ///
    /// - Throws: `AMQPConnectionError.connectionClosed` if the connection to the broker is not open,
    ///         or an `NIO` or `AMQPClient` error.
    /// - Returns: an `AnyAsyncSequence` of `String` that contains each consumed message.
    public func consume() async throws -> AnyAsyncSequence<String> {
        // Start consuming
        let consumeStream = try await connection.performConsume(configuration)

        // Wrap stream events in an AnyAsyncSequence<String>
        return AnyAsyncSequence<String>(
            consumeStream.compactMap { message in
                return String(buffer: message.body)
            }
        )
    }

    /// Start consuming from the consumer with retries.
    ///
    /// This method will attempt to reconnect/recreate the consumer if the connection to RabbitMQ is
    /// lost or if an error occurs. Only task cancellation, graceful shutdown, or the consumer completing
    /// will cause this to stop trying to consume on the broker.
    ///
    /// - Parameter retryInterval: The interval at which to retry consuming.
    /// - Throws: `AMQPConnectionError.connectionClosed` if the connection to the broker is not open,
    ///         or an `NIO` or `AMQPClient` error.
    /// - Returns: a `ConsumerChannel` of type `String` that returns each consumed message.
    public func retryingConsume(retryInterval: Duration = .seconds(30)) async throws -> ConsumerChannel<String> {
        return try await RetryingConsumer(
            connection, configuration, retryInterval
        ).consume()
    }
}
