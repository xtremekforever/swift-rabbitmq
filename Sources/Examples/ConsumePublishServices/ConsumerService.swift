import Foundation
import Logging
import RabbitMq
import ServiceLifecycle

struct ConsumerService: Service {
    private let rabbitMqConnectable: Connectable
    private let logger: Logger

    init(
        _ rabbitMqConnectable: Connectable,
        _ logger: Logger = Logger(label: "\(ConsumerService.self)")
    ) {
        self.rabbitMqConnectable = rabbitMqConnectable
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
        let connection = try await rabbitMqConnectable.waitForConnection()

        let consumer = Consumer(
            connection, "ConsumerServiceQueue", "ServiceExampleContract",
            consumerOptions: .init(noAck: true, retryInterval: .seconds(15))
        )
        for await message in try await consumer.consume().cancelOnGracefulShutdown() {
            processMessage(message)
        }
    }
}
