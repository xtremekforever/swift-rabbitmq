
import AMQPProtocol

public enum ExchangeType: Sendable {
    case fanout, direct, headers, topic
}

public struct ExchangeOptions: Sendable {
    var type:       ExchangeType
    var passive:    Bool
    var durable:    Bool
    var autoDelete: Bool
    var `internal`: Bool
    var args:       Table

    public init(type: ExchangeType = ExchangeType.direct,
                passive: Bool = false,
                durable: Bool = false,
                autoDelete: Bool = false,
                internal: Bool = false,
                args: Table = Table()) {
        self.type = type
        self.passive = passive
        self.durable = durable
        self.autoDelete = autoDelete
        self.internal = `internal`
        self.args = args
    }
}

extension ExchangeOptions {
    func exchangeDeclare(_ connection: Connection, _ exchangeName: String) async throws {
        // Don't declare exchange if name is empty
        if exchangeName.isEmpty {
            return
        }

        try await connection.reuseChannel().exchangeDeclare(
            name:       exchangeName,
            type:       "\(self.type)",
            passive:    self.passive,
            durable:    self.durable,
            autoDelete: self.autoDelete,
            internal:   self.internal,
            args:       self.args
        )
    }
}
