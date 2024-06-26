import AMQPClient
import NIO

public struct Publisher: Sendable {
    private let connection: Connection
    private let exchangeName: String
    private let exchangeOptions: ExchangeOptions

    public init(
        _ connection: Connection,
        _ exchangeName: String = "",
        exchangeOptions: ExchangeOptions = ExchangeOptions()
    ) {
        self.connection = connection
        self.exchangeName = exchangeName
        self.exchangeOptions = exchangeOptions
    }

    public func publish(_ data: String, routingKey: String = "") async throws {
        let channel = try await connection.reuseChannel()

        // Declare exchange (only if declare = true)
        try await channel.exchangeDeclare(exchangeName, exchangeOptions)

        // TODO: Implement some retry logic
        _ = try await channel.basicPublish(
            from: ByteBuffer(string: data),
            exchange: exchangeName,
            routingKey: routingKey
        )
    }
}
