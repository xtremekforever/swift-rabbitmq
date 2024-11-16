import NIOCore
import NIOSSL

/// Definition of configuration that can be provided for a RabbitMQ connection.
public struct ConnectionConfiguration: Sendable {
    /// If `nil` is passed, no TLS configuration will be used for the connection.
    public var tls: TLSConfiguration?

    /// The timeout for the connection to the broker to succeed.
    public var timeout: Duration

    /// The name or identification of the connection on the broker.
    ///
    /// If this is `nil`, the library will set the connection name to the value of `logger.label` instead.
    public var connectionName: String?

    /// Create the connection configuration.
    ///
    /// All fields use sensible defaults that work out of the box, but they can be customized
    /// as needed.
    ///
    /// - Parameters:
    ///   - tls: Optional `TLSConfiguration` to use for this connection. Defaults to `nil`.
    ///   - timeout: Specify a timeout to use for this connection. Defaults to 60 seconds.
    ///   - connectionName: Specify a name to use for this connection. Defaults to `nil`.
    public init(
        tls: TLSConfiguration? = nil,
        timeout: Duration = DefaultConnectionTimeout,
        connectionName: String? = nil
    ) {
        self.tls = tls
        self.timeout = timeout
        self.connectionName = connectionName
    }
}
