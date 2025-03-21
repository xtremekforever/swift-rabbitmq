import AMQPClient
import NIO
import NIOSSL
import Testing

@testable import RabbitMq

extension ConnectionTests {
    @Suite(.timeLimit(.minutes(1)))
    struct BasicConnectionTests {
        let logger = createTestLogger()

        @Test
        func connectsToBroker() async throws {
            try await withBasicConnection(logger: logger) { connection in
                #expect(await connection.isConnected)
            }
        }

        @Test
        func repeatedCalls() async throws {
            // This will connect, getChannel, and close twice
            try await withBasicConnection(logger: logger) { connection in
                var channel = try await connection.getChannel()
                #expect(channel != nil)

                try await connection.connect()
                channel = try await connection.getChannel()
                #expect(channel != nil)

                await connection.close()
            }
        }

        @Test
        func recofiguresConnection() async throws {
            // Connect using first URL
            try await withBasicConnection(logger: logger) { connection in
                #expect(await connection.isConnected)

                // Now reconfigure, make sure we disconnect
                let newUrl = "amqp://guest:guest@localhost:5672/%2F"
                await connection.reconfigure(with: newUrl)
                #expect(await !connection.isConnected)
                #expect(await connection.configuredUrl == newUrl)

                // Connect with new string
                try await connection.connect()
                #expect(await connection.isConnected)
            }
        }

        @Test
        func failsToConnectToInvalidHostname() async throws {
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
        func failsToConnectWithInvalidCredentials(username: String, password: String) async throws {
            let connection = BasicConnection(
                "amqp://\(username):\(password)@localhost:5672/%2F", logger: logger
            )
            await #expect(throws: AMQPConnectionError.self) {
                try await connection.connect()
            }
            #expect(await !connection.isConnected)
        }

        @Test
        func failsToConnectWithTls() async throws {
            let connection = BasicConnection("amqps://localhost:5672/%2F", logger: logger)
            await #expect(throws: NIOSSLError.self) {
                try await connection.connect()
            }
            #expect(await !connection.isConnected)
        }
    }
}
