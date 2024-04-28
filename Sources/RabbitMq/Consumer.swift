@preconcurrency
import AMQPClient
import NIO


public struct Consumer: Sendable {
    private let connection: Connection
    private let queueName: String
    private let exchangeName: String
    private let routingKey: String
    private let exchangeOptions: ExchangeOptions
    private let queueOptions: QueueOptions
    private let bindingOptions: BindingOptions
    private let consumerOptions: ConsumerOptions

    public init(_ connection: Connection,
                _ queueName: String,
                _ exchangeName: String = "",
                _ routingKey: String = "",
                exchangeOptions: ExchangeOptions = ExchangeOptions(),
                queueOptions: QueueOptions = QueueOptions(),
                bindingOptions: BindingOptions = BindingOptions(),
                consumerOptions: ConsumerOptions = ConsumerOptions()) {
        self.connection = connection
        self.queueName = queueName
        self.exchangeName = exchangeName
        self.routingKey = routingKey
        self.exchangeOptions = exchangeOptions
        self.queueOptions = queueOptions
        self.bindingOptions = bindingOptions
        self.consumerOptions = consumerOptions
    }

    public func consume() async throws -> AnyAsyncSequence<String> {
        let channel = try await connection.reuseChannel()

        // Declare exchange (only if declare = true)
        try await channel.exchangeDeclare(exchangeName, exchangeOptions)

        // Declare queue (only if declare = true)
        try await channel.queueDeclare(queueName, queueOptions)

        // Declare binding to exhange if provided
        try await channel.queueBind(queueName, exchangeName, routingKey, bindingOptions)

        // Consume on queue
        return try await AnyAsyncSequence<String>(
            // TODO: Implement some error handling and retry logic
            channel.consume(queueName, consumerOptions).compactMap() { message in 
                return String(buffer: message.body)
            }
        )
    }
}
