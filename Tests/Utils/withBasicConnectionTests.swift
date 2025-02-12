import AMQPClient
import Testing

@testable import RabbitMq

extension UtilsTests {
    @Suite(.timeLimit(.minutes(1)))
    struct withBasicConnectionTests {
        private let logger = createTestLogger()

        @Test
        func closesConnectionOnBodyExit() async throws {
            try await withBasicConnection(logger: logger) { connection in
                #expect(await connection.isConnected)
            }
        }

        @Test
        func closesConnectionOnBodyError() async throws {
            await #expect(throws: AMQPConnectionError.self) {
                try await withBasicConnection(logger: logger) { connection in
                    #expect(await connection.isConnected)
                    throw AMQPConnectionError.invalidMessage
                }
            }
        }
    }
}
