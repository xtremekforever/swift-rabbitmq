import AMQPClient
import AMQPProtocol

public struct ConsumerOptions {
    var consumerTag: String
    var noAck: Bool
    var exclusive: Bool
    var args: Table

    var exchangeOptions: ExchangeOptions
    var queueOptions: QueueOptions

    public init(consumerTag: String = "",
                noAck: Bool = false,
                exclusive: Bool = false,
                args: Table = Table(),
                exchangeOptions: ExchangeOptions = ExchangeOptions(),
                queueOptions: QueueOptions = QueueOptions()) {
        self.consumerTag = consumerTag
        self.noAck = noAck
        self.exclusive = exclusive
        self.args = args
        self.exchangeOptions = exchangeOptions
        self.queueOptions = queueOptions
    }
}

extension ConsumerOptions {
    public func consume(_ connection: Connection,
                        _ queueName: String) async throws -> AMQPSequence<AMQPClient.AMQPResponse.Channel.Message.Delivery> {
        return try await connection.reuseChannel().basicConsume(
            queue: queueName,
            consumerTag: self.consumerTag,
            noAck: self.noAck,
            exclusive: self.exclusive,
            args: self.args
        )
    }
}
