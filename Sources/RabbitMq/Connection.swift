import AMQPClient
import AsyncAlgorithms
import Foundation
import Logging
import NIO
import NIOSSL
import Semaphore
import ServiceLifecycle

let WaitForConnectionSleepInterval = Duration.milliseconds(100)
let MonitorConnectionPollInterval = Duration.milliseconds(500)

public actor Connection {
    private let url: String
    private let eventLoop: EventLoop
    private let config: AMQPConnectionConfiguration
    private let reconnectionInterval: Duration
    let logger: Logger  // shared to users of Connection

    private var channel: AMQPChannel?
    private var connection: AMQPConnection?
    private let newConsumers: AsyncChannel<Consumer>

    private let connectionSemaphore = AsyncSemaphore(value: 1)

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
        reconnectionInterval: Duration = .seconds(10),
        logger: Logger = Logger(label: "\(Connection.self)")
    ) throws {
        self.url = url
        self.eventLoop = eventLoop
        self.config = try AMQPConnectionConfiguration.init(url: url, tls: tls)
        self.reconnectionInterval = reconnectionInterval
        self.logger = logger

        self.newConsumers = AsyncChannel<Consumer>()
    }

    // Method to use to connect without monitoring, will be called when using reuseChannel()
    public func connect() async throws {
        // Semaphore is used in the context of this method to avoid multiple tasks
        // from connecting at the same time
        await connectionSemaphore.wait()
        defer { connectionSemaphore.signal() }

        if !isConnected {
            logger.info("Connecting to broker at \(url)")
            self.connection = try await AMQPConnection.connect(use: self.eventLoop, from: self.config)
            logger.info("Connected to broker at \(url)")
        }
    }

    func addConsumer(consumer: Consumer) async {
        await newConsumers.send(consumer)
    }

    public nonisolated func run() async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            // Monitor connection task
            group.addTask {
                while !Task.isCancelled && !Task.isShuttingDownGracefully {
                    // Ignore if connected
                    if await self.isConnected {
                        try await Task.sleep(for: MonitorConnectionPollInterval)
                        continue
                    }

                    // Connect or reconnect after interval
                    do {
                        try await self.connect()
                    } catch {
                        self.logger.error("Unable to connect to broker at \(self.url): \(error)")
                        try await Task.sleep(for: self.reconnectionInterval)
                    }
                }
                self.newConsumers.finish()
            }

            for try await consumer in newConsumers {
                group.addTask { try await consumer.run() }
            }

            try await group.next()
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

    public func waitForConnection() async throws {
        while !Task.isCancelled && !Task.isShuttingDownGracefully {
            try await Task.sleep(for: WaitForConnectionSleepInterval)
            if isConnected {
                break
            }
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
