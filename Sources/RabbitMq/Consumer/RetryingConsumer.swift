@preconcurrency import AMQPClient
import AsyncAlgorithms
import Logging

struct RetryingConsumer: Sendable {
    let connection: Connection
    let configuration: ConsumerConfiguration
    let logger: Logger

    let retryInterval: Duration
    let consumerChannel = ConsumerChannel(
        consumeChannel: AsyncChannel<String>(), cancellationChannel: AsyncChannel<Void>())

    init(
        _ connection: Connection,
        _ configuration: ConsumerConfiguration,
        _ retryInterval: Duration
    ) {
        self.connection = connection
        self.configuration = configuration
        self.logger = connection.logger
        self.retryInterval = retryInterval
    }

    func run() async throws {
        try await withThrowingDiscardingTaskGroup { group in
            group.addTask {
                try await self.performRetryingConsume()
                self.consumerChannel.cancellationChannel.finish()
            }

            await consumerChannel.cancellationChannel.waitUntilFinished()
            logger.debug("Received cancellation for consumer on queue \(configuration.queueName)")

            group.cancelAll()
        }
    }

    private func performRetry(_ retryInterval: Duration) async throws {
        logger.debug("Will retry consuming on queue \(configuration.queueName) in \(retryInterval)")
        try await Task.sleep(for: retryInterval)
    }

    private func performRetryingConsume() async throws {
        var firstAttempt = true

        while !Task.isCancelled && !Task.isShuttingDownGracefully {
            do {
                // Consume sequence and add to AsyncChannel
                for try await message in try await connection.performConsume(configuration) {
                    logger.trace("Consumed message from queue \(configuration.queueName): \(message)")
                    await consumerChannel.consumeChannel.send(String(buffer: message.body))
                }
                logger.debug("Consumer for queue \(configuration.queueName) completed...")

                // Exit on cancellation
                if Task.isCancelled || Task.isShuttingDownGracefully {
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
        consumerChannel.consumeChannel.finish()
    }

    func consume() async throws -> ConsumerChannel<String> {
        // Add consumer to
        await connection.addRetryingConsumer(consumer: self)
        return consumerChannel
    }
}
