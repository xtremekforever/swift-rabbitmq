
import AMQPClient

public struct Consumer {
    private let connection: Connection
    private let queueName: String

    public init(_ connection: Connection, _ queueName: String) {
        self.connection = connection
        self.queueName = queueName
    }

    public func run() async throws {

    }
}
