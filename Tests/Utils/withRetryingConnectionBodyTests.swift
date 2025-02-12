import AMQPClient
import Testing

@testable import RabbitMq

extension UtilsTests {
    @Suite(.timeLimit(.minutes(1)))
    struct withRetryingConnectionBodyTests {
        private let logger = createTestLogger()

        actor ResultCallable {
            var calledCount = 0

            func called() {
                calledCount += 1
            }

            func waitForCalledCount(_ count: Int = 1, timeout: Duration = .seconds(30)) async {
                let start = ContinuousClock().now
                while !Task.isCancelledOrShuttingDown {
                    if calledCount == count {
                        break
                    }

                    if ContinuousClock().now - start >= timeout {
                        break
                    }

                    await gracefulCancellableDelay(.milliseconds(1))
                }
            }
        }

        func withTestConnection(
            connectionPollingInterval: Duration = .milliseconds(5),
            connect: Bool = true,
            body: @escaping @Sendable (BasicConnection) async throws -> Void
        ) async throws {
            try await withBasicConnection(
                connectionPollingInterval: connectionPollingInterval, connect: connect, logger: logger
            ) { connection in
                try await body(connection)
            }
        }

        @Test
        func runsBodyWhenConnected() async throws {
            let resultCallable = ResultCallable()
            try await withTestConnection(connect: true) { connection in
                try await withRetryingConnectionBody(
                    connection, operationName: #function, retryInterval: .milliseconds(10)
                ) {
                    await resultCallable.called()
                    return true
                }

                // Connect manually
                #expect(await resultCallable.calledCount == 1)
            }
        }

        @Test
        func waitsForConnectionBeforeRunningBody() async throws {
            let resultCallable = ResultCallable()
            try await withTestConnection(connect: false) { connection in
                try await withRetryingConnectionBody(
                    connection, operationName: #function, retryInterval: .milliseconds(10)
                ) {
                    await resultCallable.called()
                    return true
                }

                // Connect manually
                #expect(await resultCallable.calledCount == 1)
            }
        }

        @Test func retriesBodyOnVoidResult() async throws {
            let resultCallable = ResultCallable()
            try await withTestConnection(connect: true) { connection in
                try await withThrowingDiscardingTaskGroup { group in
                    group.addTask {
                        // ignore cancellation error
                        try? await withRetryingConnectionBody(
                            connection, operationName: #function, retryInterval: .milliseconds(10)
                        ) {
                            await resultCallable.called()
                        }
                    }

                    await resultCallable.waitForCalledCount(5)
                    group.cancelAll()
                }
            }
        }

        @Test(arguments: [
            AMQPConnectionError.connectionClosed(replyCode: nil, replyText: "Connection failed"),
            AMQPConnectionError.channelClosed(replyCode: nil, replyText: "Channel not ready"),
        ])
        func retriesBodyOnConnectionErrors(error: AMQPConnectionError) async throws {
            let resultCallable = ResultCallable()
            try await withTestConnection { connection in
                let callCount = 10
                try await withRetryingConnectionBody(
                    connection, operationName: #function, retryInterval: .milliseconds(10)
                ) {
                    if await resultCallable.calledCount == callCount {
                        return true
                    }

                    await resultCallable.called()
                    throw error
                }

                // Connect manually
                #expect(await resultCallable.calledCount == callCount)
            }
        }

        @Test
        func taskExitsAndReturnsNilOnShutdown() async throws {
            try await withTestConnection(connect: false) { connection in
                try await withThrowingDiscardingTaskGroup { group in
                    group.addTask {
                        // Make sure we return with a result
                        let result: Void? = try await withRetryingConnectionBody(
                            connection, operationName: #function, retryInterval: .milliseconds(10)
                        ) {
                            // keep running
                        }
                        #expect(result == nil)
                    }

                    group.cancelAll()
                }
            }
        }

        @Test
        func taskThrowsCancellationErrorWhenCancelled() async throws {
            let resultCallable = ResultCallable()
            try await withTestConnection { connection in
                await #expect(throws: CancellationError.self) {
                    try await withThrowingDiscardingTaskGroup { group in
                        group.addTask {
                            // Make sure we return with a result
                            try await withRetryingConnectionBody(
                                connection, operationName: #function, retryInterval: .seconds(1)
                            ) {
                                await resultCallable.called()
                            }
                        }

                        await resultCallable.waitForCalledCount(1)

                        group.cancelAll()
                    }
                }
            }
        }
    }
}
