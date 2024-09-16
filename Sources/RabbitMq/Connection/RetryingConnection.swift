import AMQPClient
import AsyncAlgorithms
import Logging
import NIO
import NIOSSL

public actor RetryingConnection: Connection {
    private let basicConnection: BasicConnection
    private var reconnectionInterval: Duration
    public let logger: Logger  // shared to users of Connection

    public var configuredUrl: String {
        get async { await basicConnection.configuredUrl }
    }

    public var isConnected: Bool {
        get async { await basicConnection.isConnected }
    }

    public init(
        _ url: String = "",
        tls: TLSConfiguration? = nil,
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
    ) async {
        await basicConnection.reconfigure(with: url, tls: tls)

        // Update reconnection interval, this will apply on the next reconnection
        if let reconnectionInterval {
            if reconnectionInterval != self.reconnectionInterval {
                logger.debug(
                    "Changing reconnection interval from \(self.reconnectionInterval) -> \(reconnectionInterval)")
                self.reconnectionInterval = reconnectionInterval
            }
        }
    }

    public func run() async throws {
        // Monitor connection, reconnect if needed
        var lastConnectionAttempt: ContinuousClock.Instant? = nil
        while !Task.isCancelled && !Task.isShuttingDownGracefully {
            // Ignore if connected
            if await basicConnection.isConnected {
                try await Task.sleep(for: PollingConnectionSleepInterval)
                continue
            }

            // Wait until reconnection interval if we had a previous attempt
            if let lastConnectionAttempt {
                if ContinuousClock().now - lastConnectionAttempt < reconnectionInterval {
                    try await Task.sleep(for: PollingConnectionSleepInterval)
                    continue
                }
            }

            // Attempt to connect, set last attempt on failure
            do {
                try await basicConnection.connect()
                lastConnectionAttempt = nil
            } catch {
                let url = await configuredUrl
                logger.error("Unable to connect to broker at \(url): \(error)")
                lastConnectionAttempt = ContinuousClock().now
            }
        }

        // Close connection at the end
        await self.basicConnection.close()
    }

    public func getChannel() async throws -> AMQPChannel? {
        return try await basicConnection.getChannel()
    }
}
