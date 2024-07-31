@preconcurrency import AMQPClient
import AsyncAlgorithms
import Logging
import NIO

public actor Consumer: Sendable {
    private let connection: Connection
    private let queueName: String
    private let exchangeName: String
    private let routingKey: String
    private let exchangeOptions: ExchangeOptions
    private let queueOptions: QueueOptions
    private let bindingOptions: BindingOptions
    private let consumerOptions: ConsumerOptions
    private let logger: Logger

    // Retrying functionality
    private var consumeRetryInterval: Duration?
    var consumeChannel: AsyncChannel<String>?
    var cancellationChannel: AsyncChannel<Void>?

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
        self.queueName = queueName
        self.exchangeName = exchangeName
        self.routingKey = routingKey
        self.exchangeOptions = exchangeOptions
        self.queueOptions = queueOptions
        self.bindingOptions = bindingOptions
        self.consumerOptions = consumerOptions
        self.logger = connection.logger
    }

    private func performConsume() async throws -> AMQPSequence<AMQPResponse.Channel.Message.Delivery> {
        guard let channel = try await connection.getChannel() else {
            throw AMQPConnectionError.connectionClosed(replyCode: nil, replyText: nil)
        }

        // Declare exchange (only if declare = true)
        try await channel.exchangeDeclare(exchangeName, exchangeOptions, logger)

        // Declare queue (only if declare = true)
        try await channel.queueDeclare(queueName, queueOptions, logger)

        // Declare binding to exhange if provided
        try await channel.queueBind(queueName, exchangeName, routingKey, bindingOptions, logger)

        // Consume on queue
        return try await channel.consume(queueName, consumerOptions, logger)
    }

    private func performRetry(_ retryInterval: Duration) async throws {
        logger.debug("Will retry consuming on queue \(queueName) in \(retryInterval)")
        try await Task.sleep(for: retryInterval)
    }

    private func performRetryingConsume() async throws {
        guard let retryInterval = consumeRetryInterval,
            let channel = consumeChannel
        else {
            assertionFailure("Called run() with no consumeRetryInterval or consumeChannel!")
            return
        }

        var firstAttempt = true

        while !Task.isCancelled && !Task.isShuttingDownGracefully {
            do {
                // Consume sequence and add to AsyncChannel
                for try await message in try await performConsume() {
                    logger.trace("Consumed message from queue \(queueName): \(message)")
                    await channel.send(String(buffer: message.body))
                }
                logger.debug("Consumer for queue \(queueName) completed...")

                // Exit on cancellation
                if Task.isCancelled || Task.isShuttingDownGracefully {
                    break
                }

                // Consume retry
                try await performRetry(retryInterval)
            } catch AMQPConnectionError.connectionClosed(let replyCode, let replyText) {
                if !firstAttempt {
                    let error = AMQPConnectionError.connectionClosed(replyCode: replyCode, replyText: replyText)
                    logger.error("Connection closed while consuming from queue \(queueName): \(error)")
                }

                // Wait for connection, timeout after retryInterval
                await self.connection.waitForConnection(timeout: retryInterval)

                firstAttempt = false
            } catch {
                logger.error("Error consuming from queue \(queueName): \(error)")

                // Consume retry
                try await performRetry(retryInterval)
            }
        }
        channel.finish()
    }

    func run() async throws {
        try await withThrowingDiscardingTaskGroup { group in
            group.addTask {
                try await self.performRetryingConsume()
                await self.cancellationChannel?.finish()
            }

            await cancellationChannel!.waitUntilFinished()
            self.logger.debug("Received cancellation for consumer on queue \(queueName)")

            group.cancelAll()
        }
    }

    public func consume() async throws -> AnyAsyncSequence<String> {
        return AnyAsyncSequence<String>(
            try await performConsume().compactMap { message in
                return String(buffer: message.body)
            }
        )
    }

    public func retryingConsume(retryInterval: Duration = .seconds(30)) async throws -> ConsumerChannel<String> {
        self.consumeRetryInterval = retryInterval
        self.consumeChannel = AsyncChannel<String>()
        self.cancellationChannel = AsyncChannel<Void>()

        await connection.addConsumer(consumer: self)

        return ConsumerChannel(consumeChannel: consumeChannel!, cancellationChannel: cancellationChannel!)
    }
}
