import AMQPClient
import Logging

public struct Publisher: Sendable {
    let connection: Connection
    let configuration: PublisherConfiguration
    let logger: Logger

    public init(
        _ connection: Connection,
        _ exchangeName: String = "",
        exchangeOptions: ExchangeOptions = ExchangeOptions(),
        publisherOptions: PublisherOptions = PublisherOptions()
    ) {
        self.connection = connection
        self.configuration = PublisherConfiguration(
            exchangeName: exchangeName,
            exchangeOptions: exchangeOptions,
            publisherOptions: publisherOptions
        )
        self.logger = connection.logger
    }

    public func publish(_ data: String, routingKey: String = "") async throws {
        try await connection.performPublish(configuration, data, routingKey: routingKey)
    }

    public func retryingPublish(_ data: String, routingKey: String = "", retryInterval: Duration = .seconds(30))
        async throws
    {
        return try await RetryingPublisher(connection, configuration, retryInterval).publish(
            data, routingKey: routingKey)
    }
}
