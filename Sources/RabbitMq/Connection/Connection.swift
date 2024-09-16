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
        do {
            try await withTimeout(duration: timeout) {
                while !Task.isCancelled && !Task.isShuttingDownGracefully {
                    if await isConnected {
                        break
                    }
                    try await Task.sleep(for: PollingConnectionSleepInterval)
                }
            }
        } catch {
            // Ignore timeout and cancellation errors
        }
    }
}
