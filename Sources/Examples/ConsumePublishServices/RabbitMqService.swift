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
        logger.info("Starting up RabbitMqService...")

        var tls = TLSConfiguration.makeClientConfiguration()
        tls.certificateVerification = .none
        connection = try Connection(connectionUrl, tls: tls, logger: logger)

        // Connection monitoring & recovery pattern
        if let conn = connection {
            try await conn.monitorConnection(reconnectionInterval: .seconds(15))
        }

        logger.info("Shutting down RabbitMqService...")
        try await connection?.close()
    }
}
