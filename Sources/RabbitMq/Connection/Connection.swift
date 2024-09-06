import AMQPClient
import Logging

public protocol Connection: Sendable {
    var logger: Logger { get }

    func configuredUrl() async -> String
    func getChannel() async throws -> AMQPChannel?
    func waitForConnection(timeout: Duration) async
}
