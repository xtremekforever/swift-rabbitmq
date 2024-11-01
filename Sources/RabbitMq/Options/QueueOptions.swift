import AMQPProtocol

/// Options for creating a queue.
///
/// These options are used by the `Consumer`, since a queue must be defined to consume from.
/// Also, these options make it possible to define fixed configuration for many consumers
/// using this struct.
public struct QueueOptions: Sendable {
    var autoDelete: Bool
    var exclusive: Bool
    var durable: Bool
    var passive: Bool
    var args: Table

    /// Create the queue options.
    ///
    /// For more information on the options used, see the [queueDeclare](https://github.com/funcmike/rabbitmq-nio/blob/cb9c294fda00f57db116abd297df21d078b5d027/Sources/AMQPClient/AMQPChannel.swift#L333-L366)
    /// function reference which is the underlying implementation used for declaring queues.
    ///
    /// - Parameters:
    ///   - autoDelete: If `true`, the queue will be deleted when the last consumer has stopped consuming.
    ///   - exclusive: If `true`, the queue will be deleted when the channel is closed.
    ///   - durable: If `true`, the queue will be stored on disk by the broker.
    ///   - passive: If `true`, the broker will raise an exception if the queue already exists.
    ///   - args: Table of additional custom arguments to pass to the queue.
    public init(
        autoDelete: Bool = false,
        exclusive: Bool = false,
        durable: Bool = false,
        passive: Bool = false,
        args: Table = Table()
    ) {
        self.autoDelete = autoDelete
        self.exclusive = exclusive
        self.durable = durable
        self.passive = passive
        self.args = args
    }
}
