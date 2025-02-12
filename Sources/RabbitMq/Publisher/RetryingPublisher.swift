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
        return try await withRetryingConnectionBody(
            connection, operationName: "publishing to exchange \(configuration.exchangeName)",
            retryInterval: retryInterval
        ) {
            return try await connection.performPublish(configuration, data, routingKey: routingKey)
        }
    }
}
