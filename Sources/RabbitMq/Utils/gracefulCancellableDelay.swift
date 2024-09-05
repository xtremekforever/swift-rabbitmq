import AsyncAlgorithms

public func gracefulCancellableDelay(timeout: Duration) async throws {
    for await _ in AsyncTimerSequence(interval: timeout, clock: .continuous).cancelOnGracefulShutdown() {
        break
    }
}
