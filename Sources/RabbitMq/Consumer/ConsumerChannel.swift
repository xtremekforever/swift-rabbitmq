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
    public struct AsyncIterator: AsyncIteratorProtocol {
        let consumerChannel: ConsumerChannel
        var iterator: AsyncChannel<Element>.Iterator

        init(_ consumerChannel: ConsumerChannel) {
            self.consumerChannel = consumerChannel
            self.iterator = consumerChannel.consumeChannel.makeAsyncIterator()
        }

        public mutating func next() async -> Element? {
            await self.iterator.next()
        }
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(self)
    }
}
