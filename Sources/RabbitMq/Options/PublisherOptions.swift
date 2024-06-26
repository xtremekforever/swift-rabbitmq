import AMQPProtocol

public struct PublisherOptions: Sendable {
    var mandatory: Bool
    var immediate: Bool
    var properties: Properties
    var retryInterval: Duration

    public init(
        mandatory: Bool = false,
        immediate: Bool = false,
        properties: Properties = Properties(),
        retryInterval: Duration = .seconds(30)
    ) {
        self.mandatory = mandatory
        self.immediate = immediate
        self.properties = properties
        self.retryInterval = retryInterval
    }
}
