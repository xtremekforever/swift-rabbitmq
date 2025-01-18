#if canImport(Testing)
    import Testing
    import NIO
    import AMQPClient
    import NIOSSL

    @testable import RabbitMq

    @Suite(.timeLimit(.minutes(1))) struct BasicConnectionTests {
        private let logger = createTestLogger()

        func withBasicConnection(
            _ url: String = "amqp://localhost/%2F",
            body: @escaping @Sendable (BasicConnection) async throws -> Void
        ) async throws {
            let connection = BasicConnection(url, logger: logger)
            try await connection.connect()
            try await body(connection)
            await connection.close()
        }

        @Test func connectsToBroker() async throws {
            try await withBasicConnection { connection in
                #expect(await connection.isConnected)
            }
        }

        @Test func repeatedCalls() async throws {
            // This will connect, getChannel, and close twice
            try await withBasicConnection { connection in
                var channel = try await connection.getChannel()
                #expect(channel != nil)

                try await connection.connect()
                channel = try await connection.getChannel()
                #expect(channel != nil)

                await connection.close()
            }
        }

        @Test func recofiguresConnection() async throws {
            // Connect using first URL
            let originalUrl = "amqp://localhost"
            try await withBasicConnection(originalUrl) { connection in
                #expect(await connection.isConnected)
                #expect(await connection.configuredUrl == originalUrl)

                // Now reconfigure, make sure we disconnect
                let newUrl = "amqp://guest:guest@localhost/%2F"
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
            "amqp://invalid@localhost/%2F",
            "amqp://guest:invalid@localhost/%2F",
        ])
        func failsToConnectWithInvalidCredentials(url: String) async throws {
            let connection = BasicConnection(url, logger: logger)
            await #expect(throws: AMQPConnectionError.self) {
                try await connection.connect()
            }
            #expect(await !connection.isConnected)
        }

        @Test
        func failsToConnectWithTls() async throws {
            let connection = BasicConnection("amqps://localhost/%2F", logger: logger)
            await #expect(throws: NIOSSLError.self) {
                try await connection.connect()
            }
            #expect(await !connection.isConnected)
        }
    }
#endif
