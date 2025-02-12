extension AsyncSequence {
    func firstElement() async throws -> Element? {
        var iterator = makeAsyncIterator()
        return try await iterator.next()
    }
}
