import AMQPClient
import Logging

/// Default retry interval for retrying an operation on a `Connection`.
///
/// This is used by the retrying publisher and consumer as the default retry interval.
public let defaultRetryInterval = Duration.seconds(30)

/// Perform retry functionality with a given `Connection`.
///
/// This helper function can be used publicly to implement retry functionality on a body
/// that acts on or uses the passed `connection` to attempt some AMQP functionality.
/// If an `AMQPConnectionError` occurs, this method will wait for the connection before
/// trying again. Otherwise, this method will retry the operation on an interval until
/// task cancellation or graceful shutdown, or the `body` returns a value.
///
/// - Parameters:
///   - connection: The connection to monitor and use for the body.
///   - operationName: The name of the operation being performed. This is used for logging purposes to identify the operation.
///   - retryInterval: The retry interval for the `body` to be performed.
///   - body: Method body to run and retry. If the body returns a value, this method will also return a value.
/// - Throws: `CancellationError` if cancelled while performing a retry sleep interval.
/// - Returns: Value returned from the `body`, otherwise nil on cancellation or graceful shutdown.
@discardableResult public func withRetryingConnectionBody<T: Sendable>(
    _ connection: Connection,
    operationName: String,
    retryInterval: Duration = defaultRetryInterval,
    body: @escaping @Sendable () async throws -> T?
) async throws -> T? {
    var firstAttempt = true
    let firstAttemptStart = ContinuousClock().now

    // Wait for connection, timeout after retryInterval
    await connection.waitForConnection(timeout: retryInterval)

    while !Task.isCancelledOrShuttingDown {
        do {
            connection.logger.trace("Starting body for operation \"\(operationName)\"...")
            if let result = try await body(), !(result is Void) {
                return result
            }
        } catch AMQPConnectionError.connectionClosed(let replyCode, let replyText) {
            if !firstAttempt {
                let error = AMQPConnectionError.connectionClosed(replyCode: replyCode, replyText: replyText)
                connection.logger.error(
                    "Connection closed while \(operationName): \(error)"
                )
            }

            // Wait for connection, timeout after retryInterval
            await connection.waitForConnection(timeout: retryInterval)

            firstAttempt = false
            continue
        } catch {
            // If this is our first attempt to connect, keep trying until we reach the timeout
            if firstAttempt && ContinuousClock().now - firstAttemptStart < retryInterval {
                await gracefulCancellableDelay(connection.connectionPollingInterval)
                continue
            }

            connection.logger.error("Error \(operationName): \(error)")
            firstAttempt = false
        }

        // Exit on cancellation or shutdown
        if !Task.isCancelledOrShuttingDown {
            connection.logger.trace("Will retry operation \"\(operationName)\" in \(retryInterval)...")
            try await Task.sleep(for: retryInterval)
        }
    }

    return nil
}
