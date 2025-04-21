import AMQPClient
import Logging
import NIOCore

struct RetryingPublisher: ConnectionLoggable {
    let connection: Connection
    let configuration: PublisherConfiguration
    let retryInterval: Duration

    var logger: Logger {
        get async {
            await connection.logger.withMetadata(["exchangeName": .string(configuration.exchangeName)])
        }
    }

    init(
        _ connection: Connection,
        _ configuration: PublisherConfiguration,
        _ retryInterval: Duration
    ) {
        self.connection = connection
        self.configuration = configuration
        self.retryInterval = retryInterval
    }

    @discardableResult func publish(
        _ data: ByteBuffer, routingKey: String = ""
    ) async throws -> AMQPResponse.Channel.Basic.Published? {
        return try await withRetryingConnectionBody(
            connection, operationName: "publishing to exchange",
            metadata: ["exchangeName": .string(configuration.exchangeName)],
            retryInterval: retryInterval
        ) {
            let response = try await connection.performPublish(configuration, data, routingKey: routingKey)
            await logger.trace("Published message", metadata: ["published": .string("\(response)")])
            return response
        }
    }
}
