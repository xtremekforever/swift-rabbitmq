import AMQPProtocol

/// Definition of available options for publishing a message to RabbitMq.
public struct PublisherOptions: Sendable {
    var mandatory: Bool
    var immediate: Bool
    var properties: Properties

    /// Create the publisher options.
    ///
    /// For more information on the options used, see the [basicPublish](https://github.com/funcmike/rabbitmq-nio/blob/cb9c294fda00f57db116abd297df21d078b5d027/Sources/AMQPClient/AMQPChannel.swift#L62-L119)
    /// function reference which is the underlying implementation used for publishing.
    ///
    /// - Parameters:
    ///   - mandatory: If set to true, message must be able to be delivered to a queue or it will be returned.
    ///   - immediate: If set to true, message must be delivered to a consumer immediately or it will be returned.
    ///   - properties: Extra properties to define for this publisher (see [Properties.swift](https://github.com/funcmike/rabbitmq-nio/blob/main/Sources/AMQPProtocol/Properties.swift) in `rabbitmq-nio`)
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
