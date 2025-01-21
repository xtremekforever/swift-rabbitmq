import Testing

@testable import RabbitMq

extension ConnectionTests {
    @Suite(.timeLimit(.minutes(3)), .serialized) struct RetryingConnectionTests {
        static let logger = createTestLogger()
        static let rabbitMqTestContainer = RabbitMqTestContainer(logger: createTestLogger())

        static func withRetryingConnection(
            _ url: String? = nil,
            body: @escaping @Sendable (RetryingConnection, String) async throws -> Void
        ) async throws {
            let port = await rabbitMqTestContainer.port

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
        static func startRabbitMqTestContainer() async throws {
            try await startAndWaitForTestContainer(rabbitMqTestContainer)
        }

        @Test
        static func connectsToBroker() async throws {
            try await withRetryingConnection { connection, _ in
                await connection.waitForConnection(timeout: .seconds(5))
                #expect(await connection.isConnected)
                let channel = try await connection.getChannel()
                #expect(channel != nil)
            }
        }

        @Test static func performsRetryConnection() async throws {
            try await withRetryingConnection("amqp://invalid:invalid@invalid") { connection, _ in
                await connection.waitForConnection(timeout: .seconds(15))
                #expect(await connection.connectionAttempts > 1)
            }
        }

        @Test
        static func recofiguresConnection() async throws {
            // Connect using first URL
            try await withRetryingConnection { connection, port in
                await connection.waitForConnection(timeout: .seconds(5))
                #expect(await connection.isConnected)

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
            }
        }

        @Test
        static func stopRabbitMqTestContainer() async throws {
            try await rabbitMqTestContainer.stop()
        }
    }
}
