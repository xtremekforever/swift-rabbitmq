import Foundation
import Logging
import RabbitMq
import ServiceLifecycle

struct PublisherService: Service {
    private let rabbitMqConnectable: Connectable
    private let logger: Logger

    init(
        _ rabbitMqConnectable: Connectable,
        _ logger: Logger = Logger(label: "\(PublisherService.self)")
    ) {
        self.rabbitMqConnectable = rabbitMqConnectable
        self.logger = logger
    }

    func run() async throws {
        let connection = try await rabbitMqConnectable.waitForConnection()

        let publisher = Publisher(
            connection, "ServiceExampleContract"
        )

        while !Task.isShuttingDownGracefully {
            let contract = ServiceExampleContract(id: UUID(), value: "Hi there!")
            let encoder = JSONEncoder()
            if let jsonData = try? encoder.encode(contract),
                let json = String(data: jsonData, encoding: .utf8)
            {
                logger.info("Publishing contract: \(contract)")
                try await publisher.retryingPublish(json, retryInterval: .seconds(15))
                try await Task.sleep(for: .seconds(1))
            }
        }
    }
}
