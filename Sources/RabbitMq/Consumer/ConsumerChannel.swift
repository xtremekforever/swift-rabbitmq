import AsyncAlgorithms

/// Container for a retrying Consumer channel.
///
/// This is primarily returned by the `Consumer.retryingConsume` method and provides a way
/// to track a consumer that retries connecting to the broker. When this goes out of scope,
/// the consumer will automatically be terminated.
public final class ConsumerChannel<Element: Sendable>: Sendable, AsyncSequence {
    let _makeAsyncIterator: @Sendable () -> AsyncIterator
    let cancellationChannel: AsyncChannel<Void>

    init<Sequence: AsyncSequence & Sendable>(
        _ sequence: Sequence, cancellationChannel: AsyncChannel<Void>
    ) where Sequence.Element == Element {
        self._makeAsyncIterator = {
            AsyncIterator(iterator: sequence.makeAsyncIterator())
        }
        self.cancellationChannel = cancellationChannel
    }

    /// `AsyncIteratorProtocol` conformance for the `ConsumerChannel`.
    ///
    /// This makes it possible to transform the `ConsumerChannel` into an iterator
    /// for the purpose of consuming elements from the channel using a for loop.
    public struct AsyncIterator: AsyncIteratorProtocol {
        private let _next: () async -> Element?

        init<Iterator: AsyncIteratorProtocol>(iterator: Iterator) where Iterator.Element == Element {
            var itr = iterator
            self._next = { try? await itr.next() }
        }

        public mutating func next() async -> Element? {
            return await _next()
        }
    }

    public func makeAsyncIterator() -> AsyncIterator {
        return _makeAsyncIterator()
    }

    deinit {
        cancel()
    }

    public func cancel() {
        cancellationChannel.finish()
    }
}
