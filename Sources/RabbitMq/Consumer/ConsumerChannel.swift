import AsyncAlgorithms

public final class ConsumerChannel<Element: Sendable>: Sendable {
    let consumeChannel: AsyncChannel<Element>
    let cancellationChannel: AsyncChannel<Void>

    init(consumeChannel: AsyncChannel<Element>, cancellationChannel: AsyncChannel<Void>) {
        self.consumeChannel = consumeChannel
        self.cancellationChannel = cancellationChannel
    }

    deinit {
        cancel()
    }

    public func cancel() {
        cancellationChannel.finish()
    }
}

extension ConsumerChannel: AsyncSequence {
    public func makeAsyncIterator() -> AsyncChannel<Element>.AsyncIterator {
        consumeChannel.makeAsyncIterator()
    }
}
