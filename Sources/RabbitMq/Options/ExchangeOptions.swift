import AMQPProtocol

/// Enumeration for an exchange type.
public enum ExchangeType: String, Sendable {
    case fanout, direct, headers, topic
}

/// Options for creating an exchange.
///
/// These options are used by both the `Publisher` and the `Consumer`, since both require exchanges
/// to work. Also, these options make it possible to define fixed configuration for many publishers
/// or consumers using this struct.
public struct ExchangeOptions: Sendable {
    public var type: ExchangeType
    public var passive: Bool
    public var durable: Bool
    public var autoDelete: Bool
    public var `internal`: Bool
    public var args: Table

    /// Create the exchange options.
    ///
    /// For more information on the options used, see the [exchangeDeclare](https://github.com/funcmike/rabbitmq-nio/blob/cb9c294fda00f57db116abd297df21d078b5d027/Sources/AMQPClient/AMQPChannel.swift#L447-L481)
    /// function reference which is the underlying implementation used for declaring exchanges.
    ///
    /// - Parameters:
    ///   - type: The type of the exchange to define. Defaults to `.direct`.
    ///   - passive: If `true`, broker will raise an exception if the exchange already exists.
    ///   - durable: If `true`, the exchange will be stored on disk.
    ///   - autoDelete: If `true`, the exchange will automatically be deleted when the last consumer has stopped consuming.
    ///   - internal: If `true`, the exchange cannot be directly published to the client.
    ///   - args: Table of additional custom arguments to pass to the exchange.
    public init(
        type: ExchangeType = ExchangeType.direct,
        passive: Bool = false,
        durable: Bool = false,
        autoDelete: Bool = false,
        internal: Bool = false,
        args: Table = Table()
    ) {
        self.type = type
        self.passive = passive
        self.durable = durable
        self.autoDelete = autoDelete
        self.internal = `internal`
        self.args = args
    }
}
