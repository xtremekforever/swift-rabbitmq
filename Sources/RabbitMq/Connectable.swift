// Public protocol for injecting an object that can provide a connection
public protocol Connectable: Sendable {
    func getConnection() async -> Connection?
}
