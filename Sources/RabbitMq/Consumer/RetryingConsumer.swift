import AMQPClient
import AsyncAlgorithms
import Logging
import NIOCore

struct RetryingConsumer {
    let connection: Connection
    let configuration: ConsumerConfiguration
    let logger: Logger

    let retryInterval: Duration
    let consumerWaitChannel = AsyncChannel<Void>()
    let consumeChannel = AsyncChannel<AMQPResponse.Channel.Message.Delivery>()
    let cancellationChannel = AsyncChannel<Void>()

    init(
        _ connection: Connection,
        _ configuration: ConsumerConfiguration,
        _ retryInterval: Duration
    ) {
        self.connection = connection
        self.configuration = configuration
        self.retryInterval = retryInterval
        self.logger = connection.logger.withMetadata(["queueName": .string(configuration.queueName)])
    }

    func run() async throws {
        try await withThrowingDiscardingTaskGroup { group in
            group.addTask {
                try await performRetryingConsume()
            }

            await cancellationChannel.waitUntilFinished()
            logger.debug("Received cancellation for consumer")

            group.cancelAll()
        }
    }

    private func performRetryingConsume() async throws {
        try await withRetryingConnectionBody(
            connection, operationName: "consuming from queue",
            metadata: ["queueName": .string(configuration.queueName)],
            retryInterval: retryInterval
        ) {
            let consumeStream = try await performConsume()

            // Consume sequence and add to AsyncChannel
            for try await message in consumeStream {
                logger.trace("Consumed message", metadata: ["delivery": .string("\(message)")])
                await consumeChannel.send(message)
            }

            // Consumer completed, exit if the Task is cancelled
            logger.debug("Consumer completed...")
        }

        // Finish channels on exit
        consumeChannel.finish()
        cancellationChannel.finish()
    }

    private func performConsume() async throws -> AMQPSequence<AMQPResponse.Channel.Message.Delivery> {
        // This will let the `consume()` method know that we either are consuming or failed
        // Either way we want it to return
        defer { consumerWaitChannel.finish() }

        // Start consuming
        return try await connection.performConsume(configuration)
    }

    private func runAndWait() async {
        // We spin off an unstructured task here for the consumer
        // It will be invariably linked to the ConsumerChannel instance that is created
        Task { try await run() }

        // Wait for initial consume to start
        await consumerWaitChannel.waitUntilFinished()
    }

    func consumeDelivery() async throws -> ConsumerChannel<AMQPResponse.Channel.Message.Delivery> {
        await runAndWait()
        return ConsumerChannel(consumeChannel, cancellationChannel: cancellationChannel)
    }

    func consumeBuffer() async throws -> ConsumerChannel<ByteBuffer> {
        await runAndWait()
        return ConsumerChannel(consumeChannel.compactMap { $0.body }, cancellationChannel: cancellationChannel)
    }

    func consumeString() async throws -> ConsumerChannel<String> {
        await runAndWait()
        return ConsumerChannel(
            consumeChannel.compactMap { String(buffer: $0.body) }, cancellationChannel: cancellationChannel
        )
    }
}
