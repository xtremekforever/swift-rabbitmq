import AMQPClient
import AsyncAlgorithms
import Logging
import NIO
import ServiceLifecycle

public struct Consumer: Sendable {
    private let connection: Connection
    private let queueName: String
    private let exchangeName: String
    private let routingKey: String
    private let exchangeOptions: ExchangeOptions
    private let queueOptions: QueueOptions
    private let bindingOptions: BindingOptions
    private let consumerOptions: ConsumerOptions
    private let logger: Logger

    private let asyncChannel = AsyncChannel<String>()

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

    private func performRetry() async throws -> Bool {
        if let retryInterval = consumerOptions.retryInterval {
            logger.debug("Will retry consuming on queue \(queueName) in \(retryInterval)")
            try await Task.sleep(for: retryInterval)
            return true
        }

        return false
    }

    func run() async throws {
        while !Task.isCancelled {
            do {
                let sequence = try await performConsume()

                // Consume sequence and add to AsyncChannel
                for try await message in sequence {
                    logger.trace("Consumed message from queue \(queueName): \(message)")
                    await asyncChannel.send(String(buffer: message.body))
                }
                logger.warning("Consumer for queue \(queueName) completed...")

                // Exit on graceful shutdown
                if Task.isShuttingDownGracefully {
                    break
                }

                // Consume retry (if enabled)
                if try await !performRetry() {
                    break
                }
            } catch AMQPConnectionError.connectionClosed(let replyCode, let replyText) {
                let error = AMQPConnectionError.connectionClosed(replyCode: replyCode, replyText: replyText)
                logger.error("Connection closed while consuming from queue \(queueName): \(error)")

                // Wait for connection again (retry interval does not factor in when waiting for reconnection)
                if consumerOptions.retryInterval != nil {
                    try await connection.waitForConnection()
                    continue
                }

                // Otherwise rethrow error
                throw error
            } catch {
                logger.error("Error consuming from queue \(queueName): \(error)")

                // Consume retry (if enabled)
                if try await performRetry() {
                    continue
                }

                // Rethrow error if we are not retrying consume
                throw error
            }
        }
        asyncChannel.finish()
    }

    public func consume() async throws -> AsyncChannel<String> {
        await connection.addConsumer(consumer: self)
        return asyncChannel
    }
}
