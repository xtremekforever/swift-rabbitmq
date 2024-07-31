import AMQPClient
import AsyncAlgorithms
import Foundation
import Logging
import NIO
import NIOSSL
import ServiceLifecycle

let PollingConnectionSleepInterval = Duration.milliseconds(100)

public actor Connection {
    private let url: String
    private let eventLoop: EventLoop
    private let config: AMQPConnectionConfiguration
    let logger: Logger  // shared to users of Connection

    private var channel: AMQPChannel?
    private var connection: AMQPConnection?
    private let newConsumers: AsyncChannel<Consumer>

    private var connecting = false

    public var isConnected: Bool {
        if let conn = self.connection {
            return conn.isConnected
        }
        return false
    }

    public init(
        _ url: String = "",
        eventLoop: EventLoop = MultiThreadedEventLoopGroup(numberOfThreads: 1).next(),
        tls: TLSConfiguration = TLSConfiguration.makeClientConfiguration(),
        logger: Logger = Logger(label: "\(Connection.self)")
    ) throws {
        self.url = url
        self.eventLoop = eventLoop
        self.config = try AMQPConnectionConfiguration.init(url: url, tls: tls)
        self.logger = logger

        self.newConsumers = AsyncChannel<Consumer>()
    }

    // Internal use only, for retrying consumers functionality
    func addConsumer(consumer: Consumer) async {
        await newConsumers.send(consumer)
    }

    // Method to use to connect without monitoring, will be called when using reuseChannel()
    public func connect() async throws {
        if !isConnected && !connecting {
            connecting = true
            defer { connecting = false }

            logger.info("Connecting to broker at \(url)")
            self.connection = try await AMQPConnection.connect(use: self.eventLoop, from: self.config)
            logger.info("Connected to broker at \(url)")
        }
    }

    private func gracefulCancellableDelay(timeout: Duration) async throws {
        for await _ in AsyncTimerSequence(interval: timeout, clock: .continuous).cancelOnGracefulShutdown() {
            break
        }
    }

    private func monitorConnection(reconnectionInterval: Duration) async throws {
        while !Task.isCancelled && !Task.isShuttingDownGracefully {
            // Ignore if connected
            if isConnected {
                try await Task.sleep(for: PollingConnectionSleepInterval)
                continue
            }

            // Connect or reconnect after interval
            do {
                try await self.connect()
                continue
            } catch {
                logger.error("Unable to connect to broker at \(self.url): \(error)")
                try await gracefulCancellableDelay(timeout: reconnectionInterval)
            }
        }
    }

    public func run(reconnectionInterval: Duration?) async throws {
        try await withThrowingDiscardingTaskGroup { group in
            if let interval = reconnectionInterval {
                group.addTask {
                    // Monitor connection task
                    try await self.monitorConnection(reconnectionInterval: interval)

                    // Stop receiving new consumers
                    self.newConsumers.finish()

                    // Close connection at the end
                    try? await self.close()
                }
            }

            for try await consumer in newConsumers {
                group.addTask { try await consumer.run() }
            }

            // Cancel all tasks on exit
            group.cancelAll()
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
                    try await Task.sleep(for: PollingConnectionSleepInterval)
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
