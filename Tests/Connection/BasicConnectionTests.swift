import AMQPClient
import NIO
import NIOSSL
import Testing

@testable import RabbitMq

extension ConnectionTests {
    @Suite(.timeLimit(.minutes(3)), .serialized) struct BasicConnectionTests {
        static let logger = createTestLogger()
        static let rabbitMqTestContainer = RabbitMqTestContainer(logger: createTestLogger())

        static func withBasicConnection(
            _ url: String? = nil,
            body: @escaping @Sendable (BasicConnection, String) async throws -> Void
        ) async throws {
            let port = await rabbitMqTestContainer.port
            let connection = BasicConnection(url ?? "amqp://localhost:\(port)", logger: logger)
            try await connection.connect()
            try await body(connection, port)
            await connection.close()
        }

        @Test
        static func startRabbitMqTestContainer() async throws {
            try await startAndWaitForTestContainer(rabbitMqTestContainer)
        }

        @Test
        static func connectsToBroker() async throws {
            try await withBasicConnection { connection, _ in
                #expect(await connection.isConnected)
            }
        }

        @Test static func repeatedCalls() async throws {
            // This will connect, getChannel, and close twice
            try await withBasicConnection { connection, _ in
                var channel = try await connection.getChannel()
                #expect(channel != nil)

                try await connection.connect()
                channel = try await connection.getChannel()
                #expect(channel != nil)

                await connection.close()
            }
        }

        @Test
        static func recofiguresConnection() async throws {
            // Connect using first URL
            try await withBasicConnection { connection, port in
                #expect(await connection.isConnected)

                // Now reconfigure, make sure we disconnect
                let newUrl = "amqp://guest:guest@localhost:\(port)/%2F"
                await connection.reconfigure(with: newUrl)
                #expect(await !connection.isConnected)
                #expect(await connection.configuredUrl == newUrl)

                // Connect with new string
                try await connection.connect()
                #expect(await connection.isConnected)
            }
        }

        @Test
        static func failsToConnectToInvalidHostname() async throws {
            let connection = BasicConnection("amqp://aninvalidhostname/%2F", logger: logger)
            await #expect(throws: NIOConnectionError.self) {
                try await connection.connect()
            }
            #expect(await !connection.isConnected)
            let channel = try await connection.getChannel()
            #expect(channel == nil)
        }

        @Test(arguments: [
            ("guest", "invalid"), ("invalid", "guest"),
        ])
        static func failsToConnectWithInvalidCredentials(username: String, password: String) async throws {
            let port = await rabbitMqTestContainer.port
            let connection = BasicConnection(
                "amqp://\(username):\(password)@localhost:\(port)/%2F", logger: Self.logger
            )
            await #expect(throws: AMQPConnectionError.self) {
                try await connection.connect()
            }
            #expect(await !connection.isConnected)
        }

        @Test
        static func failsToConnectWithTls() async throws {
            let port = await rabbitMqTestContainer.port
            let connection = BasicConnection("amqps://localhost:\(port)/%2F", logger: logger)
            await #expect(throws: NIOSSLError.self) {
                try await connection.connect()
            }
            #expect(await !connection.isConnected)
        }

        @Test
        static func stopRabbitMqTestContainer() async throws {
            try await rabbitMqTestContainer.stop()
        }
    }
}
