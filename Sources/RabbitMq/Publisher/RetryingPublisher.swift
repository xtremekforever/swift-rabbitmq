import AMQPClient
import Logging
import NIOCore

struct RetryingPublisher: Sendable {
    let connection: Connection
    let configuration: PublisherConfiguration
    let logger: Logger
    let retryInterval: Duration

    init(
        _ connection: Connection,
        _ configuration: PublisherConfiguration,
        _ retryInterval: Duration
    ) {
        self.connection = connection
        self.configuration = configuration
        self.logger = connection.logger
        self.retryInterval = retryInterval
    }

    @discardableResult func publish(
        _ data: ByteBuffer, routingKey: String = ""
    ) async throws -> AMQPResponse.Channel.Basic.Published? {
        var firstAttempt = true

        while !Task.isCancelledOrShuttingDown {
            do {
                return try await connection.performPublish(configuration, data, routingKey: routingKey)
            } catch AMQPConnectionError.connectionClosed(let replyCode, let replyText) {
                if !firstAttempt {
                    let error = AMQPConnectionError.connectionClosed(replyCode: replyCode, replyText: replyText)
                    logger.error(
                        "Connection closed while publishing to exchange \(configuration.exchangeName): \(error)")
                }

                // Wait for connection, timeout after retryInterval
                await self.connection.waitForConnection(timeout: retryInterval)

                firstAttempt = false
            } catch {
                logger.error("Error publishing message to exchange \(configuration.exchangeName): \(error)")

                // Publish retry (if enabled)
                logger.debug("Will retry publishing to exchange \(configuration.exchangeName) in \(retryInterval)")
                try await Task.sleep(for: retryInterval)
            }
        }

        return nil
    }
}
