
import AMQPClient
import NIO

public struct Publisher: Sendable {
    private let connection: Connection
    private let exchangeName: String
    private let exchangeOptions: ExchangeOptions

    public init(_ connection: Connection,
                _ exchangeName: String = "",
                exchangeOptions: ExchangeOptions = ExchangeOptions()) {
        self.connection = connection
        self.exchangeName = exchangeName
        self.exchangeOptions = exchangeOptions
    }

    public func publish(_ data: String, routingKey: String = "") async throws {
        // Declare exchange (only if declare = true)
        try await exchangeOptions.exchangeDeclare(connection, exchangeName)

        // TODO: Implement some retry logic
        _ = try await connection.reuseChannel().basicPublish(
            from: ByteBuffer(string: data),
            exchange: exchangeName,
            routingKey: routingKey
        )
    }
}
