import Foundation
import Logging
import RabbitMq
import ServiceLifecycle

struct ConsumerService: Service {
    private let rabbitMqConnection: Connection
    private let logger: Logger
    private let retryInterval: Duration

    init(
        _ rabbitMqConnection: Connection,
        _ logger: Logger = Logger(label: "\(ConsumerService.self)"),
        retryInterval: Duration = .seconds(15)
    ) {
        self.rabbitMqConnection = rabbitMqConnection
        self.logger = logger
        self.retryInterval = retryInterval
    }

    private func processMessage(_ message: String) {
        let decoder = JSONDecoder()
        guard let data = message.data(using: .utf8) else {
            logger.error("Invalid data received: \(message)")
            return
        }
        do {
            let contract = try decoder.decode(ServiceExampleContract.self, from: data)
            logger.info("Received contract: \(contract)")
        } catch {
            logger.error("Unable to parse contract: \(error)")
        }
    }

    func run() async throws {
        let consumer = Consumer(
            rabbitMqConnection, "ConsumerServiceQueue", "ServiceExampleContract"
        )

        let events = try await consumer.retryingConsume(retryInterval: retryInterval)
        for await message in events.cancelOnGracefulShutdown() {
            processMessage(message)
        }
    }
}
