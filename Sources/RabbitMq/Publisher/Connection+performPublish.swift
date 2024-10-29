import AMQPClient
import NIOCore

extension Connection {
    func performPublish(_ configuration: PublisherConfiguration, _ buffer: ByteBuffer, routingKey: String = "")
        async throws
    {
        guard let channel = try await getChannel() else {
            throw AMQPConnectionError.connectionClosed(replyCode: nil, replyText: nil)
        }

        // Declare exchange (only if exchangeName is not empty)
        try await channel.exchangeDeclare(configuration.exchangeName, configuration.exchangeOptions, logger)

        // Publish the message
        _ = try await channel.publish(
            buffer,
            configuration.exchangeName,
            routingKey,
            configuration.publisherOptions,
            logger
        )
    }
}
