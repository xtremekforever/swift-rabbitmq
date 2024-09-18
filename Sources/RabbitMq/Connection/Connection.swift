import AMQPClient
import Logging

// This is the default for all connections, but can be customized per-connection
// to increase responsiveness or reduce CPU usage.
public let DefaultConnectionPollingInterval = Duration.milliseconds(250)

public protocol Connection: Sendable {
    var logger: Logger { get }
    var connectionPollingInterval: Duration { get }

    var configuredUrl: String { get async }
    var isConnected: Bool { get async }

    func waitForConnection(timeout: Duration) async
    func getChannel() async throws -> AMQPChannel?
}

extension Connection {
    public func waitForConnection(timeout: Duration) async {
        let start = ContinuousClock().now
        while !Task.isCancelledOrShuttingDown {
            if await isConnected {
                break
            }

            if ContinuousClock().now - start >= timeout {
                break
            }

            await gracefulCancellableDelay(connectionPollingInterval)
        }
    }
}
