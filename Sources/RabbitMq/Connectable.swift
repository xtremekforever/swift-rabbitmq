// Public protocol for injecting an object that can provide a connection
public protocol Connectable: Sendable {
    func getConnection() async -> Connection?
    func waitForConnection() async throws -> Connection
}

extension Connectable {
    // This implementation will wait forever for the connection to exist + be connected to the broker
    public func waitForConnection() async throws -> Connection {
        if let conn = await getConnection(), await conn.isConnected() {
            return conn
        }

        try await Task.sleep(for: WaitForConnectionSleepInterval)
        return try await waitForConnection()
    }
}
