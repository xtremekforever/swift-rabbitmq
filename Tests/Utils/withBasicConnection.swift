import Logging
import RabbitMq

func withBasicConnection(
    _ url: String = "amqp://localhost/%2F",
    logger: Logger,
    body: @escaping @Sendable (BasicConnection) async throws -> Void
) async throws {
    let connection = BasicConnection(url, logger: logger)
    try await connection.connect()
    do {
        try await body(connection)
    } catch {
        await connection.close()
        throw error
    }
    await connection.close()
}
