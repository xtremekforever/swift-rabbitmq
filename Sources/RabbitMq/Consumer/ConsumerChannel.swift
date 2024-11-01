import AsyncAlgorithms

/// Container for a retrying Consumer channel.
///
/// This is primarily returned by the `Consumer.retryingConsume` method and provides a way
/// to track a consumer that retries connecting to the broker. When this goes out of scope,
/// the consumer will automatically be terminated.
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
    /// `AsyncIteratorProtocol` conformance for the `ConsumerChannel`.
    ///
    /// This makes it possible to transform the `ConsumerChannel` into an iterator
    /// for the purpose of consuming elements from the channel using a for loop.
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
