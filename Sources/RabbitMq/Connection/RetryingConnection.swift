import AMQPClient
import AsyncAlgorithms
import Logging
import NIO
import NIOSSL

public actor RetryingConnection: Connection {
    private let basicConnection: BasicConnection
    private var reconnectionInterval: Duration
    public let logger: Logger  // shared to users of Connection

    private var lastConnectionAttempt: ContinuousClock.Instant? = nil

    public init(
        _ url: String = "",
        tls: TLSConfiguration = TLSConfiguration.makeClientConfiguration(),
        eventLoop: EventLoop = MultiThreadedEventLoopGroup.singleton.next(),
        reconnectionInterval: Duration = .seconds(30),
        logger: Logger = Logger(label: "\(RetryingConnection.self)")
    ) throws {
        self.basicConnection = try BasicConnection(url, tls: tls, eventLoop: eventLoop, logger: logger)
        self.reconnectionInterval = reconnectionInterval
        self.logger = logger
    }

    public func reconfigure(
        with url: String, tls: TLSConfiguration? = nil, reconnectionInterval: Duration? = nil
    ) async throws {
        try await basicConnection.reconfigure(with: url, tls: tls)

        // Update reconnection interval, this will apply on the next reconnection
        if let reconnectionInterval {
            logger.debug("Changing reconnection interval from \(self.reconnectionInterval) -> \(reconnectionInterval)")
            self.reconnectionInterval = reconnectionInterval
        }
    }

    public func run() async throws {
        // Monitor connection, reconnect if needed
        let timerSequence = AsyncTimerSequence(interval: PollingConnectionSleepInterval, clock: .continuous)
        for await _ in timerSequence.cancelOnGracefulShutdown() {
            // Ignore if connected
            if await basicConnection.isConnected {
                continue
            }

            // Wait until reconnection interval if we had a previous attempt
            if let lastConnectionAttempt {
                if ContinuousClock().now - lastConnectionAttempt < reconnectionInterval {
                    continue
                }
            }

            // Attempt to connect, set last attempt on failure
            do {
                try await basicConnection.connect()
                lastConnectionAttempt = nil
            } catch {
                let url = await basicConnection.configuredUrl()
                logger.error("Unable to connect to broker at \(url): \(error)")
                lastConnectionAttempt = ContinuousClock().now
            }
        }

        // Close connection at the end
        try? await self.basicConnection.close()
    }

    public func configuredUrl() async -> String {
        return await basicConnection.configuredUrl()
    }

    public func getChannel() async throws -> AMQPChannel? {
        return try await basicConnection.getChannel()
    }

    public func waitForConnection(timeout: Duration) async {
        await basicConnection.waitForConnection(timeout: timeout)
    }
}
