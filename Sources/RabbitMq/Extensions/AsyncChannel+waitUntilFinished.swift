import AsyncAlgorithms

extension AsyncChannel {
    func waitUntilFinished() async {
        for await _ in self {}
    }
}
