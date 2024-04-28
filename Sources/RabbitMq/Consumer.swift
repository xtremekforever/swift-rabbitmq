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
        // Declare exchange (only if declare = true)
        try await exchangeOptions.exchangeDeclare(connection, exchangeName)

        // Declare queue (only if declare = true)
        try await queueOptions.queueDeclare(connection, queueName)

        // Declare binding to exhange if provided
        try await bindingOptions.queueBind(connection, queueName, exchangeName, routingKey)

        // Consume on queue
        return try await AnyAsyncSequence<String>(
            // TODO: Implement some error handling and retry logic
            consumerOptions.consume(connection, queueName).compactMap() { message in 
                return String(buffer: message.body)
            }
        )
    }
}
