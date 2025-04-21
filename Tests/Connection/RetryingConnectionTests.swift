import Testing

@testable import RabbitMq

extension ConnectionTests {
    @Suite(.timeLimit(.minutes(1)))
    struct RetryingConnectionTests {
        let logger = createTestLogger(logLevel: .critical)

        func withRetryingConnection(
            _ url: String? = nil,
            body: @escaping @Sendable (RetryingConnection, String) async throws -> Void
        ) async throws {
            let port = "5672"

            let connection = RetryingConnection(
                url ?? "amqp://localhost:\(port)", reconnectionInterval: .seconds(1), logger: logger
            )
            try await withThrowingDiscardingTaskGroup { group in
                group.addTask { await connection.run() }
                try await body(connection, port)
                group.cancelAll()
            }
        }

        @Test
        func connectsToBroker() async throws {
            try await withRetryingConnection { connection, _ in
                await connection.waitForConnection(timeout: .seconds(5))
                #expect(await connection.isConnected)
                #expect(await connection.logger[metadataKey: "url"] != nil)
                let channel = try await connection.getChannel()
                #expect(channel != nil)
            }
        }

        @Test
        func performsRetryConnection() async throws {
            try await withRetryingConnection("amqp://invalid:invalid@invalid") { connection, _ in
                await connection.waitForConnection(timeout: .seconds(15))
                #expect(await connection.connectionAttempts > 1)
            }
        }

        @Test
        func recofiguresConnection() async throws {
            // Connect using first URL
            try await withRetryingConnection { connection, port in
                await connection.waitForConnection(timeout: .seconds(5))
                #expect(await connection.isConnected)
                let origUrl = await connection.configuredUrl
                try #expect(#require(await connection.logger[metadataKey: "url"]) == .string(origUrl))

                // Now reconfigure, make sure we disconnect
                let newUrl = "amqp://guest:guest@localhost:\(port)/%2F"
                let newReconnectionInterval = Duration.milliseconds(750)
                await connection.reconfigure(with: newUrl, reconnectionInterval: newReconnectionInterval)
                #expect(await !connection.isConnected)
                #expect(await connection.configuredUrl == newUrl)
                #expect(await connection.reconnectionInterval == newReconnectionInterval)

                // Wait for reconnection with new string
                await connection.waitForConnection(timeout: .seconds(5))
                #expect(await connection.isConnected)
                try #expect(#require(await connection.logger[metadataKey: "url"]) == .string(newUrl))
            }
        }
    }
}
