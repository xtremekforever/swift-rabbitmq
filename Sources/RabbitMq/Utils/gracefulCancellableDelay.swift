import AsyncAlgorithms
import ServiceLifecycle

/// Delay the current task supporting graceful shutdown.
///
/// - Parameters:
///   - timeout: The Duration to delay the current task
public func gracefulCancellableDelay(_ timeout: Duration) async {
    await cancelWhenGracefulShutdown {
        do {
            try await Task.sleep(for: timeout)
        } catch {
            // Ignore errors
        }
    }
}
