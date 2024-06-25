import AMQPClient
import Foundation
import Logging
import NIO
import NIOSSL
import Semaphore

public actor Connection {
    private let url: String
    private let eventLoop: EventLoop
    private let config: AMQPConnectionConfiguration
    let logger: Logger  // shared to users of Connection

    private var channel: AMQPChannel?
    private var connection: AMQPConnection?

    private let connectionSemaphore = AsyncSemaphore(value: 1)

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
    }

    public func isConnected() -> Bool {
        if let conn = self.connection {
            return conn.isConnected
        }
        return false
    }

    public func reuseChannel() async throws -> AMQPChannel {
        // Use semaphore in the context of this method to avoid multiple tasks
        // from connecting at the same time
        await connectionSemaphore.wait()
        defer {
            connectionSemaphore.signal()
        }

        guard let channel = self.channel, channel.isOpen else {
            if self.connection == nil || self.connection!.isConnected {
                // Close existing connection before starting a new one
                try await connection?.close()

                // Connect
                logger.debug("Connecting to broker at \(url)")
                self.connection = try await AMQPConnection.connect(
                    use: self.eventLoop, from: self.config)
            }

            self.channel = try await connection!.openChannel()
            return self.channel!
        }
        return channel
    }

    public func close() async throws {
        if isConnected() {
            logger.debug("Closing connection to \(url)")
            try await connection?.close()
            try await channel?.close()
        }

        // Cleanup
        self.connection = nil
        self.channel = nil
    }
}
