import Foundation
import Logging
import RabbitMq
import ServiceLifecycle

struct ConsumerService: Service {
    private let rabbitMqConnection: Connection
    private let logger: Logger

    init(
        _ rabbitMqConnection: Connection,
        _ logger: Logger = Logger(label: "\(ConsumerService.self)")
    ) {
        self.rabbitMqConnection = rabbitMqConnection
        self.logger = logger
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
        let consumer = RetryingConsumer(
            rabbitMqConnection, "ConsumerServiceQueue", "ServiceExampleContract",
            consumerOptions: .init(noAck: true), retryInterval: .seconds(15)
        )

        let events = try await consumer.consume()
        for await message in events.cancelOnGracefulShutdown() {
            processMessage(message)
        }
    }
}
