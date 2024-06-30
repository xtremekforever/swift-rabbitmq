import AMQPProtocol

public struct ConsumerOptions: Sendable {
    var consumerTag: String
    var noAck: Bool
    var exclusive: Bool
    var args: Table
    var retryInterval: Duration?

    public init(
        consumerTag: String = "",
        noAck: Bool = false,
        exclusive: Bool = false,
        args: Table = Table(),
        retryInterval: Duration? = nil
    ) {
        self.consumerTag = consumerTag
        self.noAck = noAck
        self.exclusive = exclusive
        self.args = args
        self.retryInterval = retryInterval
    }
}
