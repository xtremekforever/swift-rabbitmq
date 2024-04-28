import AMQPProtocol

public struct QueueOptions: Sendable {
    var autoDelete: Bool
    var exclusive:  Bool
    var durable:    Bool
    var passive:    Bool
    var args:       Table

    public init(autoDelete: Bool = false,
                exclusive: Bool = false,
                durable: Bool = false,
                passive: Bool = false,
                args: Table = Table()) {
        self.autoDelete = autoDelete
        self.exclusive = exclusive
        self.durable = durable
        self.passive = passive
        self.args = args
    }
}
