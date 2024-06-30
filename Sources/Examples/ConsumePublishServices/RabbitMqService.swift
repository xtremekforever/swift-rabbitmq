import Logging
import NIOSSL
import RabbitMq
import ServiceLifecycle

actor RabbitMqService: Service, Connectable {
    private let connectionUrl: String
    private let logger: Logger
    private var connection: Connection?

    init(
        _ connectionUrl: String,
        _ logger: Logger = Logger(label: String(describing: RabbitMqService.self))
    ) {
        self.connectionUrl = connectionUrl
        self.logger = logger
    }

    func getConnection() -> Connection? {
        return connection
    }

    func run() async throws {
        var tls = TLSConfiguration.makeClientConfiguration()
        tls.certificateVerification = .none
        connection = try Connection(connectionUrl, tls: tls, logger: logger)

        logger.info("Starting up RabbitMqService...")

        // Connection monitoring & recovery pattern
        while !Task.isShuttingDownGracefully {
            if let conn = self.connection {
                if await conn.isConnected() {
                    try await Task.sleep(for: .seconds(1))
                    continue
                }

                do {
                    try await conn.connect()
                } catch {
                    logger.error("Unable to connect to broker at \(connectionUrl): \(error)")
                    try await Task.sleep(for: .seconds(10))
                }
            }
        }

        logger.info("Shutting down RabbitMqService...")
        try await connection?.close()
    }
}
