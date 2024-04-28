
import AMQPProtocol

public struct BindingOptions: Sendable {
    var args: Table

    public init(args: Table = Table()) {
        self.args = args
    }
}
