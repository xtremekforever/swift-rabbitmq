import AMQPClient

extension Connection {
    func performConsume(
        _ configuration: ConsumerConfiguration
    ) async throws -> AMQPSequence<AMQPResponse.Channel.Message.Delivery> {
        let channel = try await getChannel()

        // Declare exchange (only if declare = true)
        try await channel.exchangeDeclare(configuration.exchangeName, configuration.exchangeOptions, logger)

        // Declare queue (only if declare = true)
        try await channel.queueDeclare(configuration.queueName, configuration.queueOptions, logger)

        // Declare binding to exhange if provided
        try await channel.queueBind(
            configuration.queueName, configuration.exchangeName, configuration.routingKey, configuration.bindingOptions,
            logger)

        // Consume on queue
        return try await channel.consume(configuration.queueName, configuration.consumerOptions, logger)
    }
}
