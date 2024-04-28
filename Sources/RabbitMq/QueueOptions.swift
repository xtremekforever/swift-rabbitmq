import AMQPProtocol

public struct QueueOptions {
    var declare:    Bool
    var autoDelete: Bool
    var exclusive:  Bool
    var durable:    Bool
    var passive:    Bool
    var args:       Table

    public init(declare: Bool = true,
                autoDelete: Bool = false,
                exclusive: Bool = false,
                durable: Bool = false,
                passive: Bool = false,
                args: Table = Table()) {
        self.declare = declare
        self.autoDelete = autoDelete
        self.exclusive = exclusive
        self.durable = durable
        self.passive = passive
        self.args = args
    }
}

extension QueueOptions {
    func queueDeclare(_ connection: Connection, _ queueName: String) async throws {
        if !self.declare { 
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
