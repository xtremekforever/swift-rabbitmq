import AMQPClient
import AsyncAlgorithms
import Logging
import NIOCore

public struct RetryingConsumer: Sendable {
    let connection: Connection
    let configuration: ConsumerConfiguration
    let logger: Logger
    let retryInterval: Duration

    let consumerWaitChannel = AsyncChannel<Void>()
    let consumeChannel = AsyncChannel<AMQPResponse.Channel.Message.Delivery>()
    let cancellationChannel = AsyncChannel<Void>()

    public init(
        _ connection: Connection,
        _ queueName: String,
        _ exchangeName: String = "",
        _ routingKey: String = "",
        exchangeOptions: ExchangeOptions = ExchangeOptions(),
        queueOptions: QueueOptions = QueueOptions(),
        bindingOptions: BindingOptions = BindingOptions(),
        consumerOptions: ConsumerOptions = ConsumerOptions(),
        retryInterval: Duration
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
        self.retryInterval = retryInterval
    }

    func run() async throws {
        try await withThrowingDiscardingTaskGroup { group in
            group.addTask {
                try await self.performRetryingConsume()
                self.cancellationChannel.finish()
            }

            await cancellationChannel.waitUntilFinished()
            logger.debug("Received cancellation for consumer on queue \(configuration.queueName)")

            group.cancelAll()
        }
    }

    private func performRetry(_ retryInterval: Duration) async throws {
        logger.debug("Will retry consuming on queue \(configuration.queueName) in \(retryInterval)")
        try await Task.sleep(for: retryInterval)
    }

    private func performConsume() async throws -> AMQPSequence<AMQPResponse.Channel.Message.Delivery> {
        // This will let the `consume()` method know that we either are consuming or failed
        // Either way we want it to return
        defer {
            consumerWaitChannel.finish()
        }

        // Start consuming
        return try await connection.performConsume(configuration)
    }

    private func performRetryingConsume() async throws {
        var firstAttempt = true

        while !Task.isCancelledOrShuttingDown {
            do {
                let consumeStream = try await performConsume()

                // Consume sequence and add to AsyncChannel
                for try await message in consumeStream {
                    logger.trace("Consumed message from queue \(configuration.queueName): \(message)")
                    await consumeChannel.send(message)
                }

                // Consumer completed, exit if the Task is cancelled
                logger.debug("Consumer for queue \(configuration.queueName) completed...")
                if Task.isCancelledOrShuttingDown {
                    break
                }

                // Consume retry
                try await performRetry(retryInterval)
            } catch AMQPConnectionError.connectionClosed(let replyCode, let replyText) {
                if !firstAttempt {
                    let error = AMQPConnectionError.connectionClosed(replyCode: replyCode, replyText: replyText)
                    logger.error("Connection closed while consuming from queue \(configuration.queueName): \(error)")
                }

                // Wait for connection, timeout after retryInterval
                await connection.waitForConnection(timeout: retryInterval)

                firstAttempt = false
            } catch {
                logger.error("Error consuming from queue \(configuration.queueName): \(error)")

                // Consume retry
                try await performRetry(retryInterval)
            }
        }
        consumeChannel.finish()
    }

    private func runAndWait() async {
        // We spin off an unstructured task here for the consumer
        // It will be invariably linked to the ConsumerChannel instance that is created
        Task { try await run() }

        // Wait for initial consume to start
        await consumerWaitChannel.waitUntilFinished()
    }

    public func consumeDelivery() async throws -> ConsumerChannel<AMQPResponse.Channel.Message.Delivery> {
        await runAndWait()
        return ConsumerChannel(consumeChannel, cancellationChannel: cancellationChannel)
    }

    public func consumeBuffer() async throws -> ConsumerChannel<ByteBuffer> {
        await runAndWait()
        return ConsumerChannel(consumeChannel.compactMap { $0.body }, cancellationChannel: cancellationChannel)
    }

    public func consume() async throws -> ConsumerChannel<String> {
        await runAndWait()
        return ConsumerChannel(
            consumeChannel.compactMap { String(buffer: $0.body) }, cancellationChannel: cancellationChannel
        )
    }
}
