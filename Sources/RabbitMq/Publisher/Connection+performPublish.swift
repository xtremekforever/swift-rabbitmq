import AMQPClient
import NIO

extension Connection {
    func performPublish(_ configuration: PublisherConfiguration, _ data: String, routingKey: String = "")
        async throws
    {
        guard let channel = try await getChannel() else {
            throw AMQPConnectionError.connectionClosed(replyCode: nil, replyText: nil)
        }

        // Declare exchange (only if declare = true)
        try await channel.exchangeDeclare(configuration.exchangeName, configuration.exchangeOptions, logger)

        // Publish the message
        _ = try await channel.publish(
            ByteBuffer(string: data),
            configuration.exchangeName,
            routingKey,
            configuration.publisherOptions,
            logger
        )
    }
}
