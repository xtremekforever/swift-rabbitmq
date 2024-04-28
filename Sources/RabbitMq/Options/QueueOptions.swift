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

extension QueueOptions {
    func queueDeclare(_ connection: Connection, _ queueName: String) async throws {
        // Don't declare queue if name is empty
        if queueName.isEmpty { 
            return
        }

        try await connection.reuseChannel().queueDeclare(
            name: queueName,
            passive: self.passive,
            durable: self.durable,
            exclusive: self.exclusive,
            autoDelete: self.autoDelete,
            args: self.args
        )
    }
}
