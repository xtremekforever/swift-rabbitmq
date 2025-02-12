import Logging

public func withBasicConnection(
    _ url: String = "amqp://localhost/%2F",
    configuration: ConnectionConfiguration = .init(),
    connectionPollingInterval: Duration = defaultConnectionPollingInterval,
    connect: Bool = true,
    logger: Logger,
    body: @escaping @Sendable (BasicConnection) async throws -> Void
) async throws {
    let connection = BasicConnection(
        url, configuration: configuration, logger: logger, connectionPollingInterval: connectionPollingInterval
    )

    // This is useful for testing scenarios where the connection is not "connected"
    if connect {
        try await connection.connect()
    }

    do {
        try await body(connection)
    } catch {
        await connection.close()
        throw error
    }
    await connection.close()
}
