import AsyncAlgorithms

/// Delay the current task supporting graceful shutdown.
///
/// - Parameters:
///   - timeout: The Duration to delay the current task
public func gracefulCancellableDelay(_ timeout: Duration) async {
    for await _ in AsyncTimerSequence(interval: timeout, clock: .continuous).cancelOnGracefulShutdown() {
        break
    }
}
