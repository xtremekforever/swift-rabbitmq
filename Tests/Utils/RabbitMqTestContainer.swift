import Logging
import RabbitMq
import Semaphore
import Testcontainers

actor RabbitMqTestContainer {
    let logger: Logger

    private var container: GenericContainer? = nil
    private let connectionSemaphore = AsyncSemaphore(value: 1)
    private(set) var port: String = ""

    init(logger: Logger) {
        self.logger = logger
    }

    func start() async throws -> String {
        await connectionSemaphore.wait()
        defer { connectionSemaphore.signal() }

        if container != nil { return port }

        container = try GenericContainer(image: "rabbitmq:3-alpine", port: 5672, logger: logger)
        guard let container else { return "" }

        // Start the container
        let response = try await container.start().get()
        logger.debug("Started RabbitMq container with name: \(response.Name)")

        port = response.NetworkSettings.Ports["5672/tcp"]??.first?.HostPort ?? ""
        return port
    }

    func stop() async throws {
        if let container {
            logger.debug("Stopping RabbitMq container...")
            _ = try await container.remove().get()
        }
    }
}

func startAndWaitForTestContainer(_ rabbitMqTestContainer: RabbitMqTestContainer) async throws {
    let port = try await rabbitMqTestContainer.start()

    // TODO: Remove this once we have wait strategies
    let connection = BasicConnection("amqp://localhost:\(port)", logger: rabbitMqTestContainer.logger)
    while !Task.isCancelled {
        do {
            try await connection.connect()
        } catch {
            try await Task.sleep(for: .seconds(1))
            continue
        }
        break
    }
    await connection.close()
}
