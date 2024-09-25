import AMQPProtocol

/// Options for binding a queue to an exchange.
///
/// This is used as part of the `Consumer` configuration options.
public struct BindingOptions: Sendable {
    var args: Table

    public init(args: Table = Table()) {
        self.args = args
    }
}
