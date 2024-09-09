import AMQPClient
import Foundation
import Logging
import NIO
import NIOSSL
import ServiceLifecycle
import Semaphore

public actor BasicConnection: Connection {
    private var url: String
    private var tls: TLSConfiguration?
    private let eventLoop: EventLoop
    public let logger: Logger  // shared to users of Connection

    private var channel: AMQPChannel?
    private var connection: AMQPConnection?

    private var connecting = false
    private let channelSemaphore = AsyncSemaphore(value: 1)

    public var configuredUrl: String {
        return url
    }

    public var isConnected: Bool {
        if let conn = self.connection {
            return conn.isConnected
        }
        return false
    }

    public init(
        _ url: String = "",
        tls: TLSConfiguration? = nil,
        eventLoop: EventLoop = MultiThreadedEventLoopGroup.singleton.next(),
        logger: Logger = Logger(label: "\(BasicConnection.self)")
    ) throws {
        self.url = url
        self.tls = tls
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
        connection = try await AMQPConnection.connect(
            use: eventLoop,
            from: AMQPConnectionConfiguration(url: url, tls: tls)
        )
        logger.info("Connected to broker at \(url)")
    }

    public func reconfigure(with url: String, tls: TLSConfiguration? = nil) async {
        // If the URL changes
        if url != self.url {
            logger.debug("Received call to reconfigure connection from \(self.url) -> \(url)")

            // Close any existing connection
            await close()
        }

        // Update configuration
        self.url = url
        self.tls = tls
    }

    public func getChannel() async throws -> AMQPChannel? {
        // Not connected
        guard isConnected else {
            return nil
        }

        // Ensure that only one task can open the channel at a time
        await channelSemaphore.wait()
        defer { channelSemaphore.signal() }

        // We're connected, let's reuse the channel
        guard let channel = self.channel, channel.isOpen else {
            // Then open a channel
            self.channel = try await connection!.openChannel()
            return self.channel!
        }
        return channel
    }

    public func close() async {
        if !isConnected {
            return
        }

        logger.info("Closing connection to \(url)")
        try? await connection?.close()
        try? await channel?.close()
    }
}
