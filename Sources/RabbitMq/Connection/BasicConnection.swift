import AMQPClient
import Foundation
import Logging
import NIO
import NIOCore
import NIOSSL
import Semaphore
import ServiceLifecycle

/// Basic connection to a RabbitMQ broker. Does not provide any connection recovery.
///
/// Usage example:
/// ```swift
/// let basicConnection = BasicConnection("amqp://localhost/%2f")
/// try await basicConnection.connect()
/// // create a Publisher or Consumer passing the basicConnection to it
/// ```
public actor BasicConnection: Connection {
    private var url: String
    private var configuration: ConnectionConfiguration
    private let eventLoop: EventLoop

    // Protocol conformances
    public let logger: Logger  // shared to users of Connection
    public let connectionPollingInterval: Duration
    public var configuredUrl: String {
        return url
    }

    public var isConnected: Bool {
        if let conn = self.connection {
            return conn.isConnected
        }
        return false
    }

    private var channel: AMQPChannel?
    private var connection: AMQPConnection?

    private var connecting = false
    private var reconfiguring = false
    private let channelSemaphore = AsyncSemaphore(value: 1)

    /// Create a `BasicConnection` instance.
    ///
    /// - Parameters:
    ///   - url: URL to use to connect to RabbitMQ. Example: `amqp://localhost/%2f`
    ///   - configuration: Customize configuration for this connection, including TLS configuration, timeout, and connection name.
    ///   - eventLoop: Event loop to use for internal futures API of `rabbitmq-nio`.
    ///   - logger: Logger to use for this connection and all consumers/publishers associated to this connection.
    ///   - connectionPollingInterval: Interval to use to poll for connection. *Must* be greater than 0 milliseconds.
    public init(
        _ url: String,
        configuration: ConnectionConfiguration = .init(),
        eventLoop: EventLoop = MultiThreadedEventLoopGroup.singleton.next(),
        logger: Logger = Logger(label: String(describing: BasicConnection.self)),
        connectionPollingInterval: Duration = DefaultConnectionPollingInterval
    ) {
        assert(connectionPollingInterval > .milliseconds(0))

        self.url = url
        self.configuration = configuration
        self.eventLoop = eventLoop
        self.logger = logger
        self.connectionPollingInterval = connectionPollingInterval
    }

    /// Perform a connection to the RabbitMQ broker.
    ///
    /// This method does not provide any connection recovery. It is protected from
    /// actor reentrancy to ensure that more than a single connection is not started
    /// by different calling tasks.
    ///
    /// - Throws: `AMQPConnectionError` if unable to connect.
    public func connect() async throws {
        if isConnected || connecting || reconfiguring {
            return
        }

        // Guarded by this flag on the actor
        connecting = true
        defer { connecting = false }

        // Actually connect
        logger.info("Connecting to broker at \(url)")
        connection = try await AMQPConnection.connect(
            use: eventLoop,
            from: AMQPConnectionConfiguration(
                url: url, tls: configuration.tls,
                timeout: TimeAmount(configuration.timeout),
                connectionName: configuration.connectionName ?? logger.label
            )
        )
        logger.info("Connected to broker at \(url)")
    }

    /// Reconfigure this connection to RabbitMQ.
    ///
    /// If the URL changes from the previously configured URL, any open connections will
    /// be closed. It will need to be reopened manually by calling `connect()` again.
    ///
    /// - Parameters:
    ///   - url: URL to use to connect to RabbitMQ. Example: `amqp://localhost/%2f`
    ///   - tls: Optional `TLSConfiguration` to use for connection.
    public func reconfigure(with url: String, configuration: ConnectionConfiguration = .init()) async {
        // Reset reconfiguring flag when exiting
        defer {
            reconfiguring = false
        }

        // If the URL changes
        if url != self.url {
            logger.debug("Received call to reconfigure connection from \(self.url) -> \(url)")

            // While this flag is true, connect() will not be allowed to connect
            reconfiguring = true

            // Close any existing connection
            await close()
        }

        // Update configuration before closing connection
        self.url = url
        self.configuration = configuration
    }

    /// Open or get a channel instance for the current connection.
    ///
    /// If the channel already exists it will be returned. If not, a new channel will be
    /// opened. This method is protected from actor reentrancy to ensure that multiple
    /// channels are not created by multiple concurrent tasks.
    ///
    /// - Throws: `AMQPConnectionError` if unable to connect.
    /// - Returns: `AMQPChannel` if the channel could be opened or already exists.
    public func getChannel() async throws -> AMQPChannel {
        // Not connected
        guard isConnected else {
            throw AMQPConnectionError.connectionClosed(replyCode: nil, replyText: nil)
        }

        // We're connected, let's reuse the channel
        guard let channel = self.channel, channel.isOpen else {
            // Ensure that only one task can open the channel at a time
            await channelSemaphore.wait()
            defer { channelSemaphore.signal() }

            // Then open a channel
            self.channel = try await connection!.openChannel()
            return self.channel!
        }
        return channel
    }

    /// Close connection to RabbitMQ.
    ///
    /// This method does nothing if not connected to RabbitMQ. It will also close the
    /// channel if it is open.
    public func close() async {
        if !isConnected {
            return
        }

        logger.info("Closing connection to \(url)")
        try? await connection?.close()
        try? await channel?.close()
    }
}
