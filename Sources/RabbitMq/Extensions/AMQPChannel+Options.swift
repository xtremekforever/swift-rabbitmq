import AMQPClient
import Logging
import NIO

extension AMQPChannel {
    public func exchangeDeclare(
        _ exchangeName: String,
        _ exchangeOptions: ExchangeOptions,
        _ logger: Logger
    ) async throws {
        // Don't declare exchange if name is empty
        if exchangeName.isEmpty {
            return
        }

        logger.trace(
            "Declaring exchange...",
            metadata: ["name": .string(exchangeName), "options": .string("\(exchangeOptions)")]
        )
        try await exchangeDeclare(
            name: exchangeName,
            type: exchangeOptions.type.rawValue,
            passive: exchangeOptions.passive,
            durable: exchangeOptions.durable,
            autoDelete: exchangeOptions.autoDelete,
            internal: exchangeOptions.internal,
            args: exchangeOptions.args
        )
    }

    public func queueDeclare(
        _ queueName: String,
        _ queueOptions: QueueOptions,
        _ logger: Logger
    ) async throws {
        // Don't declare queue if name is empty
        if queueName.isEmpty {
            return
        }

        logger.trace(
            "Declaring queue...",
            metadata: ["name": .string(queueName), "options": .string("\(queueOptions)")]
        )
        try await queueDeclare(
            name: queueName,
            passive: queueOptions.passive,
            durable: queueOptions.durable,
            exclusive: queueOptions.exclusive,
            autoDelete: queueOptions.autoDelete,
            args: queueOptions.args
        )
    }

    public func queueBind(
        _ queueName: String,
        _ exchangeName: String,
        _ routingKey: String,
        _ bindingOptions: BindingOptions,
        _ logger: Logger
    ) async throws {
        // Can't bind queue if queue name or exchange name is empty
        if queueName.isEmpty || exchangeName.isEmpty {
            return
        }

        logger.trace(
            "Binding queue to exchange",
            metadata: [
                "queueName": .string(queueName),
                "exchangeName": .string(exchangeName),
                "options": .string("\(bindingOptions)"),
            ]
        )
        try await queueBind(
            queue: queueName,
            exchange: exchangeName,
            routingKey: routingKey,
            args: bindingOptions.args
        )
    }

    public func consume(
        _ queueName: String,
        _ consumerOptions: ConsumerOptions,
        _ logger: Logger
    ) async throws -> AMQPSequence<AMQPClient.AMQPResponse.Channel.Message.Delivery> {
        logger.trace("Consuming messages from queue...", metadata: ["name": .string(queueName)])
        return try await basicConsume(
            queue: queueName,
            consumerTag: consumerOptions.consumerTag,
            noAck: consumerOptions.autoAck,
            exclusive: consumerOptions.exclusive,
            args: consumerOptions.args
        )
    }

    public func publish(
        _ data: ByteBuffer,
        _ exchangeName: String = "",
        _ routingKey: String = "",
        _ publisherOptions: PublisherOptions,
        _ logger: Logger
    ) async throws -> AMQPResponse.Channel.Basic.Published {
        logger.trace("Publishing message to exchange...", metadata: ["name": .string(exchangeName)])
        return try await basicPublish(
            from: data,
            exchange: exchangeName,
            routingKey: routingKey,
            mandatory: publisherOptions.mandatory,
            immediate: publisherOptions.immediate,
            properties: publisherOptions.properties
        )
    }
}
