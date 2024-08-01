import AMQPProtocol

public struct PublisherOptions: Sendable {
    var mandatory: Bool
    var immediate: Bool
    var properties: Properties

    public init(
        mandatory: Bool = false,
        immediate: Bool = false,
        properties: Properties = Properties()
    ) {
        self.mandatory = mandatory
        self.immediate = immediate
        self.properties = properties
    }
}
