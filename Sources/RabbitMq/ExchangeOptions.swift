
import AMQPProtocol

public enum ExchangeType {
    case fanout, direct, headers, topic
}

public struct ExchangeOptions {
    var declare:    Bool
    var name:       String
    var type:       ExchangeType
    var passive:    Bool
    var durable:    Bool
    var autoDelete: Bool
    var `internal`: Bool
    var args:       Table

    public init(declare: Bool = false,
                name: String = "",
                type: ExchangeType = ExchangeType.direct,
                passive: Bool = false,
                durable: Bool = false,
                autoDelete: Bool = false,
                internal: Bool = false,
                args: Table = Table()) {
        self.declare = declare
        self.name = name
        self.type = type
        self.passive = passive
        self.durable = durable
        self.autoDelete = autoDelete
        self.internal = `internal`
        self.args = args
    }
}

extension ExchangeOptions {
    func exchangeDeclare(_ connection: Connection) async throws {
        if !self.declare { 
            return
        }

        try await connection.reuseChannel().exchangeDeclare(
            name:       self.name,
            type:       "\(self.type)",
            passive:    self.passive,
            durable:    self.durable,
            autoDelete: self.autoDelete,
            internal:   self.internal,
            args:       self.args
        )
    }
}
