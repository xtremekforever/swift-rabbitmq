import AMQPProtocol

public struct ConsumerOptions: Sendable {
    var consumerTag: String
    var noAck: Bool
    var exclusive: Bool
    var args: Table
    var reconnectionInterval: Duration

    public init(
        consumerTag: String = "",
        noAck: Bool = false,
        exclusive: Bool = false,
        args: Table = Table(),
        reconnectionInterval: Duration = .seconds(30)
    ) {
        self.consumerTag = consumerTag
        self.noAck = noAck
        self.exclusive = exclusive
        self.args = args
        self.reconnectionInterval = reconnectionInterval
    }
}
