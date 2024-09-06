import AMQPClient
import AsyncAlgorithms
import Foundation
import Logging
import NIO
import NIOSSL
import ServiceLifecycle

let PollingConnectionSleepInterval = Duration.milliseconds(100)

public protocol Connection: Sendable {
    var logger: Logger { get }

    func getChannel() async throws -> AMQPChannel?
    func waitForConnection(timeout: Duration) async
}

public actor BasicConnection: Connection {
    private(set) public var url: String
    private var config: AMQPConnectionConfiguration
    private let eventLoop: EventLoop
    public let logger: Logger  // shared to users of Connection

    private var channel: AMQPChannel?
    private var connection: AMQPConnection?

    private var connecting = false
    private var lastConnectionAttempt: ContinuousClock.Instant? = nil

    public var isConnected: Bool {
        if let conn = self.connection {
            return conn.isConnected
        }
        return false
    }

    public init(
        _ url: String = "",
        tls: TLSConfiguration = TLSConfiguration.makeClientConfiguration(),
        eventLoop: EventLoop = MultiThreadedEventLoopGroup.singleton.next(),
        logger: Logger = Logger(label: "\(Connection.self)")
    ) throws {
        self.url = url
        self.config = try AMQPConnectionConfiguration.init(url: url, tls: tls)
        self.eventLoop = eventLoop
        self.logger = logger
    }

    // Method to use to connect without monitoring
    public func connect() async throws {
        if isConnected || connecting {
            return
        }

        // Guarded by this flag on the actor
        connecting = true
        defer { connecting = false }

        // Actually connect
        logger.info("Connecting to broker at \(url)")
        self.connection = try await AMQPConnection.connect(use: self.eventLoop, from: self.config)
        logger.info("Connected to broker at \(url)")
    }

    public func reconfigure(with url: String, tls: TLSConfiguration = TLSConfiguration.makeClientConfiguration())
        async throws
    {
        logger.debug("Received call to reconfigure connection from \(self.url) -> \(url)")

        // Close existing connection
        if isConnected {
            logger.info("Closing existing connection to \(url)")
            try await connection?.close()
            try await channel?.close()
        }

        // Update URL and connection
        self.url = url
        self.config = try AMQPConnectionConfiguration.init(url: url, tls: tls)

        // This is set to make monitorConnection() reconnect immediately
        lastConnectionAttempt = nil
    }

    private func monitorConnection(reconnectionInterval: Duration) async throws {
        for await _ in AsyncTimerSequence(interval: PollingConnectionSleepInterval, clock: .continuous)
            .cancelOnGracefulShutdown()
        {
            // Ignore if connected
            if isConnected {
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
                try await self.connect()
                lastConnectionAttempt = nil
            } catch {
                logger.error("Unable to connect to broker at \(self.url): \(error)")
                lastConnectionAttempt = ContinuousClock().now
            }
        }
    }

    public func run(reconnectionInterval: Duration?) async throws {
        try await withThrowingDiscardingTaskGroup { group in
            if let interval = reconnectionInterval {
                group.addTask {
                    // Monitor connection task
                    try await self.monitorConnection(reconnectionInterval: interval)

                    // Close connection at the end
                    try? await self.close()
                }
            }
        }
    }

    public func getChannel() async throws -> AMQPChannel? {
        // Not connected
        guard isConnected else {
            return nil
        }

        // We're connected, let's reuse the channel
        guard let channel = self.channel, channel.isOpen else {
            // Then open a channel
            self.channel = try await connection!.openChannel()
            return self.channel!
        }
        return channel
    }

    public func waitForConnection(timeout: Duration) async {
        do {
            try await withTimeout(duration: timeout) {
                while !Task.isCancelled && !Task.isShuttingDownGracefully {
                    if self.isConnected {
                        break
                    }
                    try await gracefulCancellableDelay(timeout: PollingConnectionSleepInterval)
                }
            }
        } catch {
            // Ignore timeout and cancellation errors
        }
    }

    public func close() async throws {
        if !isConnected {
            return
        }

        logger.info("Closing connection to \(url)")
        try await connection?.close()
        try await channel?.close()
    }
}
