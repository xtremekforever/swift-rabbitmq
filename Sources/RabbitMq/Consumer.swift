
import AMQPClient
import NIO


public struct Consumer: Sendable {
    private let connection: Connection
    private let queueName: String
    private let consumerOptions: ConsumerOptions

    public init(_ connection: Connection,
                _ queueName: String,
                consumerOptions: ConsumerOptions = ConsumerOptions()) {
        self.connection = connection
        self.queueName = queueName
        self.consumerOptions = consumerOptions
    }

    public func consume() async throws -> AnyAsyncSequence<String> {
        // Declare exchange (only if declare = true)
        try await consumerOptions.exchangeOptions.exchangeDeclare(connection)

        // Declare queue (only if declare = true)
        try await consumerOptions.queueOptions.queueDeclare(connection, queueName)

        // Declare binding
        try await connection.reuseChannel().queueBind(
            queue: queueName, 
            exchange: consumerOptions.exchangeOptions.name
        )

        // Consume on queue
        return try await AnyAsyncSequence<String>(
            consumerOptions.consume(connection, queueName).compactMap() { message in 
                return String(buffer: message.body)
            }
        )
    }
}
