import Logging
import NIOSSL
import RabbitMq
import ServiceLifecycle

// Service that creates RabbitMq connection & monitors it until shutdown
struct RabbitMqService: Service {
    private let connectionUrl: String
    private let logger: Logger
    private let reconnectionInterval: Duration
    public let connection: RetryingConnection

    init(
        _ connectionUrl: String,
        _ logger: Logger = Logger(label: String(describing: RabbitMqService.self)),
        reconnectionInterval: Duration = .seconds(15)
    ) {
        self.connectionUrl = connectionUrl
        self.logger = logger
        self.reconnectionInterval = reconnectionInterval

        var tls = TLSConfiguration.makeClientConfiguration()
        tls.certificateVerification = .none
        connection = RetryingConnection(
            connectionUrl, configuration: .init(tls: tls), reconnectionInterval: reconnectionInterval, logger: logger
        )
    }

    func getConnection() -> Connection? {
        return connection
    }

    func run() async throws {
        logger.info("Starting up RabbitMqService...")

        // Connection monitoring & recovery pattern
        await connection.run()

        logger.info("Shutting down RabbitMqService...")
    }
}
