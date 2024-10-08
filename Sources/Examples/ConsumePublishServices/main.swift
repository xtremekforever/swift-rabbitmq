import Foundation
import Logging
import ServiceLifecycle

struct ServiceExampleContract: Codable {
    let id: UUID
    let value: String
}

var logger = Logger(label: "ConsumePublishServices")
logger.logLevel = .info

let rabbitMqService = RabbitMqService("amqp://guest:guest@localhost/%2f", logger)
let consumerService = ConsumerService(rabbitMqService.connection, logger)
let publisherService = PublisherService(rabbitMqService.connection, logger)
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
