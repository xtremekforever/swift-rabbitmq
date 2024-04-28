
import AMQPProtocol

public struct BindingOptions: Sendable {
    var args: Table

    public init(args: Table = Table()) {
        self.args = args
    }
}

extension BindingOptions {
    public func queueBind(_ connection: Connection,
                          _ queueName: String,
                          _ exchangeName: String,
                          _ routingKey: String) async throws {
        // Can't bind queue if queue name or exchange name is empty
        if queueName.isEmpty || exchangeName.isEmpty {
            return
        }

        try await connection.reuseChannel().queueBind(
            queue: queueName, 
            exchange: exchangeName,
            routingKey: routingKey
        )
    }
}