/// Type erasing wrapper for async sequences.
///
/// Any errors from the base sequence are not propagated, but will
/// terminate iteration.
///
public struct AnyAsyncSequence<Element>: AsyncSequence, Sendable {
    public typealias AsyncIterator = AnyAsyncIterator<Element>
    public typealias Element = Element

    let _makeAsyncIterator: @Sendable () -> AnyAsyncIterator<Element>

    public struct AnyAsyncIterator<IteratorElement>: AsyncIteratorProtocol {
        typealias IteratorElement = Element

        private let _next: () async -> IteratorElement?

        init<I: AsyncIteratorProtocol>(itr: I) where I.Element == IteratorElement {
            var itr = itr
            self._next = {  try? await itr.next() }
        }

        public mutating func next() async -> IteratorElement? {
            return await _next()
        }
    }


    init<S: AsyncSequence & Sendable>(_ seq: S) where S.Element == Element {
        _makeAsyncIterator = {
            AnyAsyncIterator(itr: seq.makeAsyncIterator())
        }
    }

    public func makeAsyncIterator() -> AnyAsyncIterator<Element> {
        return _makeAsyncIterator()
    }
}
