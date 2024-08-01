// Public protocol for injecting an object that can provide a connection
public protocol Connectable: Sendable {
    func getConnection() async -> Connection?
    func waitGetConnection() async throws -> Connection
}

extension Connectable {
    // This implementation will wait forever for the connection to exist
    public func waitGetConnection() async throws -> Connection {
        while !Task.isCancelled && !Task.isShuttingDownGracefully {
            if let conn = await getConnection() {
                return conn
            }

            try await Task.sleep(for: PollingConnectionSleepInterval)
        }

        throw CancellationError()
    }
}
