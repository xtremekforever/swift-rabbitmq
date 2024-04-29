import AMQPClient
import AMQPProtocol

public struct ConsumerOptions: Sendable {
    var consumerTag: String
    var noAck: Bool
    var exclusive: Bool
    var args: Table

    public init(
        consumerTag: String = "",
        noAck: Bool = false,
        exclusive: Bool = false,
        args: Table = Table()
    ) {
        self.consumerTag = consumerTag
        self.noAck = noAck
        self.exclusive = exclusive
        self.args = args
    }
}
