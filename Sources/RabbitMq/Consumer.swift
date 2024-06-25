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

    private var consumerTask: Task<Void, Error>?

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

    private func consumerSequence() async throws -> AMQPSequence<AMQPResponse.Channel.Message.Delivery> {
        do {
            let channel = try await self.connection.reuseChannel()

            // Declare exchange (only if declare = true)
            self.logger.trace("Declaring exchange \(self.exchangeName) with options: \(exchangeOptions)")
            try await channel.exchangeDeclare(exchangeName, exchangeOptions)

            // Declare queue (only if declare = true)
            logger.trace("Declaring queue \(queueName) with options: \(queueOptions)")
            try await channel.queueDeclare(queueName, queueOptions)

            // Declare binding to exhange if provided
            logger.trace(
                "Binding queue \(queueName) to exchange \(exchangeName) with options: \(bindingOptions)")
            try await channel.queueBind(queueName, exchangeName, routingKey, bindingOptions)

            // Consume on queue
            logger.debug("Consuming messages from queue \(queueName)...")
            return try await channel.consume(queueName, consumerOptions)
        } catch AMQPConnectionError.connectionClosed {
            logger.error("Connection closed while consuming from queue \(queueName)")

            // Close connection
            try await connection.close()
        } catch {
            logger.error("Error consuming from queue \(queueName): \(error)")
        }

        try await Task.sleep(for: consumerOptions.reconnectionInterval)
        return try await consumerSequence()
    }

    private func monitorConnection(_ asyncChannel: AsyncChannel<String>) {
        Task {
            while !Task.isCancelled {
                if await !connection.isConnected() {
                    startConsumerTask(asyncChannel)
                    break
                }
                try await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    private func startConsumerTask(_ asyncChannel: AsyncChannel<String>) {
        if let task = consumerTask {
            task.cancel()
        }

        consumerTask = Task {
            while !Task.isCancelled {
                let sequence = try await consumerSequence()

                // Monitor the connection
                monitorConnection(asyncChannel)

                // Consume sequence and add to AsyncChannel
                for try await message in sequence {
                    logger.trace("Consumed message from queue \(queueName): \(message)")
                    await asyncChannel.send(String(buffer: message.body))
                }
            }
            asyncChannel.finish()
        }
    }

    public func consume() async throws -> AsyncChannel<String> {
        let asyncChannel = AsyncChannel<String>()

        startConsumerTask(asyncChannel)

        return asyncChannel
    }
}
