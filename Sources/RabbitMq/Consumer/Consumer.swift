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
    let channel: AMQPChannel
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
    ) async throws {
        self.channel = try await connection.getChannel()
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

        // Declare exchange (only if declare = true)
        try await channel.exchangeDeclare(configuration.exchangeName, configuration.exchangeOptions, logger)

        // Declare queue (only if declare = true)
        try await channel.queueDeclare(configuration.queueName, configuration.queueOptions, logger)

        // Declare binding to exhange if provided
        try await channel.queueBind(
            configuration.queueName, configuration.exchangeName, configuration.routingKey,
            configuration.bindingOptions, logger
        )
    }

    private func performConsume() async throws -> AMQPSequence<AMQPResponse.Channel.Message.Delivery> {
        try await channel.consume(configuration.queueName, configuration.consumerOptions, logger)
    }

    /// Start consuming strings from the consumer (no retries).
    ///
    /// - Throws: `AMQPConnectionError.connectionClosed` if the connection to the broker is not open,
    ///         or an `NIO` or `AMQPClient` error.
    /// - Returns: an `AnyAsyncSequence` of `String` that contains each consumed message.
    public func consume() async throws -> AnyAsyncSequence<String> {
        // We starting consuming before wrapping the stream below
        let consumeStream = try await performConsume()
        return .init(consumeStream.compactMap { String(buffer: $0.body) })
    }

    /// Start consuming from the consumer (no retries).
    ///
    /// - Throws: `AMQPConnectionError.connectionClosed` if the connection to the broker is not open,
    ///         or an `NIO` or `AMQPClient` error.
    /// - Returns: an `AnyAsyncSequence` of `ByteBuffer` that contains each consumed message.
    public func consumeBuffer() async throws -> AnyAsyncSequence<ByteBuffer> {
        // We starting consuming before wrapping the stream below
        let consumeStream = try await performConsume()
        return .init(consumeStream.compactMap { $0.body })
    }

    /// Start consuming delivery messages from the consumer (no retries).
    ///
    /// - Throws: `AMQPConnectionError.connectionClosed` if the connection to the broker is not open,
    ///         or an `NIO` or `AMQPClient` error.
    /// - Returns: an `AnyAsyncSequence` of `AMQPResponse.Channel.Message.Delivery` that contains each consumed message.
    public func consumeDelivery() async throws -> AnyAsyncSequence<AMQPResponse.Channel.Message.Delivery> {
        // We starting consuming before wrapping the stream below
        let consumeStream = try await performConsume()
        return .init(consumeStream)
    }
}
