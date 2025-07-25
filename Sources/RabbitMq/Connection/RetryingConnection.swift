import AMQPClient
import AsyncAlgorithms
import Logging
import NIO
import NIOSSL
import ServiceLifecycle

/// Retrying connection to a RabbitMQ broker. Provides full connection recovery patterns.
///
/// Usage example:
/// ```swift
/// let retryingConnection = RetryingConnection("amqp://localhost/%2f", reconnectionInterval: .seconds(15))
/// await withDiscardingTaskGroup { group in
///     group.addTask { await retryingConnection.run() }
///     // other tasks for consuming/publishing here
/// }
/// ```
/// A task or task group can be used to `run()` the connection, but [swift-service-lifecycle](https://github.com/swift-server/swift-service-lifecycle)
/// can also be used to run the connection with full graceful shutdown support.
public actor RetryingConnection: Connection, Service {
    private let basicConnection: BasicConnection
    private(set) var reconnectionInterval: Duration
    private(set) var connectionAttempts: Int = 0

    // Protocol conformances
    public let connectionPollingInterval: Duration
    public nonisolated var logger: Logger { basicConnection.logger }
    public var configuredUrl: String {
        get async { await basicConnection.configuredUrl }
    }
    public var isConnected: Bool {
        get async { await basicConnection.isConnected }
    }

    /// Create a `RetryingConnection` instance.
    ///
    /// - Parameters:
    ///   - url: URL to use to connect to RabbitMQ. Example: `amqp://localhost/%2f`
    ///   - configuration: Customize configuration for this connection, including TLS configuration, timeout, and connection name.
    ///   - eventLoop: Event loop to use for internal futures API of `rabbitmq-nio`.
    ///   - reconnectionInterval: Interval to use to reconnect to broker or connection error or lost connection.
    ///   - logger: Logger to use for this connection and all consumers/publishers associated to this connection.
    ///   - connectionPollingInterval: Interval to use to poll for connection. *Must* be greater than 0 seconds.
    public init(
        _ url: String,
        configuration: ConnectionConfiguration = .init(),
        eventLoop: EventLoop = MultiThreadedEventLoopGroup.singleton.next(),
        reconnectionInterval: Duration = .seconds(30),
        logger: Logger = Logger(label: "\(RetryingConnection.self)"),
        connectionPollingInterval: Duration = defaultConnectionPollingInterval
    ) {
        assert(connectionPollingInterval > .seconds(0))

        self.basicConnection = BasicConnection(url, configuration: configuration, eventLoop: eventLoop, logger: logger)
        self.reconnectionInterval = reconnectionInterval
        self.connectionPollingInterval = connectionPollingInterval
    }

    /// Reconfigure this connection to RabbitMQ.
    ///
    /// If the URL changes from the previously configured URL, any open connections will
    /// be closed. If the `reconnectionInterval` changes, the new interval will apply immediately.
    ///
    /// - Parameters:
    ///   - url: URL to use to connect to RabbitMQ. Example: `amqp://localhost/%2f`
    ///   - tls: Optional `TLSConfiguration` to use for connection.
    ///   - reconnectionInterval: Interval to use to reconnect to broker or connection error or lost connection.
    public func reconfigure(
        with url: String, configuration: ConnectionConfiguration = .init(), reconnectionInterval: Duration? = nil
    ) async {
        // Update reconnection interval, this will apply on the next reconnection
        if let reconnectionInterval {
            if reconnectionInterval != self.reconnectionInterval {
                logger.debug(
                    "Changing reconnection interval",
                    metadata: [
                        "currentInterval": .stringConvertible(self.reconnectionInterval),
                        "newInterval": .stringConvertible(reconnectionInterval),
                    ]
                )
                self.reconnectionInterval = reconnectionInterval
            }
        }

        // Reconfigure connection after updating our own configuration
        await basicConnection.reconfigure(with: url, configuration: configuration)
    }

    /// Method to connect to RabbitMQ and provide connection recovery and monitoring.
    ///
    /// Uses the configured `reconnectionInterval` to restore connection to the broker
    /// after failing to connect or losing connection. The connection will be monitored
    /// using the `connectionPollingInterval`.
    ///
    /// This task supports graceful shutdown for easy integration into for applications
    /// that use `ServiceLifecycle`.
    ///
    public func run() async {
        var lastConnectionAttempt: ContinuousClock.Instant? = nil

        // Monitor connection, reconnect if needed
        while !Task.isCancelledOrShuttingDown {
            // Ignore if connected
            if await basicConnection.isConnected {
                await gracefulCancellableDelay(connectionPollingInterval)
                continue
            }

            // Wait until reconnection interval if we had a previous attempt
            if let lastConnectionAttempt {
                if ContinuousClock().now - lastConnectionAttempt < reconnectionInterval {
                    await gracefulCancellableDelay(connectionPollingInterval)
                    continue
                }
            }

            // Attempt to connect, set last attempt on failure
            do {
                try await basicConnection.connect()
                connectionAttempts = 0
                lastConnectionAttempt = nil
            } catch {
                let url = await configuredUrl
                logger.error(
                    "Unable to connect to broker", metadata: ["url": .string(url), "error": .string("\(error)")]
                )
                lastConnectionAttempt = ContinuousClock().now
            }
            connectionAttempts += 1
        }

        // Close connection at the end
        await self.basicConnection.close()
    }

    /// Open or get a channel instance for the current connection.
    ///
    /// If the channel already exists it will be returned. If not, a new channel will be
    /// opened. This method is protected from actor reentrancy to ensure that multiple
    /// channels are not created by multiple concurrent tasks.
    ///
    /// - Throws: `AMQPConnectionError` if unable to connect.
    /// - Returns: `AMQPChannel` if the channel could be opened or already exists. `nil` otherwise.
    public func getChannel() async throws -> AMQPChannel? {
        return try await basicConnection.getChannel()
    }
}
