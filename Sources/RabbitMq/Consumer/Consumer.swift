@preconcurrency import AMQPClient
import AsyncAlgorithms
import Logging
import NIO

public struct Consumer: Sendable {
    let connection: Connection
    let configuration: ConsumerConfiguration
    let logger: Logger

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

    public func consume() async throws -> AnyAsyncSequence<String> {
        // Setup the consumer before returning the AsyncSequence
        try await connection.setupConsumer(configuration)

        // Consume and wrap in AsyncString
        return AnyAsyncSequence<String>(
            try await connection.performConsume(configuration).compactMap { message in
                return String(buffer: message.body)
            }
        )
    }

    public func retryingConsume(retryInterval: Duration = .seconds(30)) async throws -> ConsumerChannel<String> {
        return try await RetryingConsumer(
            connection, configuration, retryInterval
        ).consume()
    }
}
