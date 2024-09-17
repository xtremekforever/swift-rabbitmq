import AsyncAlgorithms

public func gracefulCancellableDelay(_ timeout: Duration) async {
    for await _ in AsyncTimerSequence(interval: timeout, clock: .continuous) {
        break
    }
}
