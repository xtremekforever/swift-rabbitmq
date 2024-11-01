import AMQPProtocol

/// Options for binding a queue to an exchange.
///
/// This is used as part of the `Consumer` configuration options.
public struct BindingOptions: Sendable {
    var args: Table

    /// Create the binding options for the queue.
    ///
    /// - Parameter args: Table of custom arguments to provide for binding the queue to the exchange.
    ///   See [Table.swift](https://github.com/funcmike/rabbitmq-nio/blob/main/Sources/AMQPProtocol/Table.swift) from `rabbitmq-nio` for more information.
    public init(args: Table = Table()) {
        self.args = args
    }
}
