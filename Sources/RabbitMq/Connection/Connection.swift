import AMQPClient
import Logging

let PollingConnectionSleepInterval = Duration.milliseconds(250)

public protocol Connection: Sendable {
    var logger: Logger { get }

    var configuredUrl: String { get async }
    var isConnected: Bool { get async }

    func waitForConnection(timeout: Duration) async
    func getChannel() async throws -> AMQPChannel?
}

extension Connection {
    public func waitForConnection(timeout: Duration) async {
        let start = ContinuousClock().now
        for await _ in pollingSequence(interval: PollingConnectionSleepInterval).cancelOnGracefulShutdown() {
            if await isConnected {
                break
            }

            // Timeout
            if ContinuousClock().now - start >= timeout {
                break
            }
        }
    }
}
