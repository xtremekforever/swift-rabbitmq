import ArgumentParser
import Foundation
import Logging
import ServiceLifecycle

struct ServiceExampleContract: Codable {
    let id: UUID
    let value: String
}

@main
struct ConsumePublishServices: AsyncParsableCommand {
    @Option
    var rabbitUrl: String = "amqp://guest:guest@localhost/%2F"

    @Option
    var logLevel: String = "info"

    @Option(help: "The reconnection interval to use for the RabbitMQ connection in seconds.")
    var reconnectionInterval: Int = 15

    @Option(help: "The retry interval to use for the consumer and publisher in seconds.")
    var retryInterval: Int = 15

    @Option(help: "The interval at which to publish the test message in milliseconds.")
    var publishInterval: Int = 1000

    // Customizable log level
    func createLogger() -> Logger {
        var logger = Logger(label: String(describing: Self.self))
        logger.logLevel = Logger.Level(rawValue: logLevel) ?? .info
        return logger
    }

    mutating func run() async throws {
        let logger = createLogger()

        let rabbitMqService = RabbitMqService(
            rabbitUrl, logger, reconnectionInterval: .seconds(self.reconnectionInterval)
        )

        let retryInterval = Duration.seconds(self.retryInterval)
        let consumerService = ConsumerService(
            rabbitMqService.connection, logger,
            retryInterval: retryInterval
        )
        let publisherService = PublisherService(
            rabbitMqService.connection, logger,
            retryInterval: retryInterval,
            publishInterval: .milliseconds(self.publishInterval)
        )
        let serviceGroup = ServiceGroup(
            configuration: .init(
                services: [
                    .init(service: rabbitMqService),
                    .init(service: consumerService),
                    .init(service: publisherService),
                ],
                gracefulShutdownSignals: [.sigterm],
                logger: logger
            )
        )
        try await serviceGroup.run()
    }
}
