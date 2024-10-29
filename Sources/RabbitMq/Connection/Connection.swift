import AMQPClient
import Logging

/// This is the default for all connections, but can be customized per-connection
/// to increase responsiveness or reduce CPU usage.
public let DefaultConnectionPollingInterval = Duration.milliseconds(250)

/// Abstraction for a high-level connection to RabbitMQ.
///
/// This protocol is used by the `Consumer` and `Publisher` to be able to get a channel
/// connection to RabbitMQ for all functionality.
///
public protocol Connection: Sendable {
    /// Required by `Consumer` and `Publisher` for logging purposes.
    var logger: Logger { get }

    /// The interval to use for polling the connection. Used by `waitForConnection()`.
    var connectionPollingInterval: Duration { get }

    /// The URL for the RabbitMQ connection that was configured.
    var configuredUrl: String { get async }

    /// Whether or not we are connected to RabbitMQ using the provided configuration.
    var isConnected: Bool { get async }

    /// Wait for connection to RabbitMQ broker.
    ///
    /// - Parameters:
    ///   - timeout: Duration to wait for connection before timing out.
    func waitForConnection(timeout: Duration) async

    /// Get channel for the current RabbitMQ connection.
    ///
    /// - Returns: `AMQPChannel` if connected, `nil` otherwise.
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
