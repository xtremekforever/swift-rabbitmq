import AsyncAlgorithms

public func gracefulCancellableDelay(timeout: Duration) async {
    for await _ in AsyncTimerSequence(interval: timeout, clock: .continuous).cancelOnGracefulShutdown() {
        break
    }
}
