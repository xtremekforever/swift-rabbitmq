import Logging
import NIOSSL
import RabbitMq
import ServiceLifecycle

// Service that creates RabbitMq connection & monitors it until shutdown
struct RabbitMqService: Service {
    private let connectionUrl: String
    private let logger: Logger
    public let connection: BasicConnection

    init(
        _ connectionUrl: String,
        _ logger: Logger = Logger(label: String(describing: RabbitMqService.self))
    ) throws {
        self.connectionUrl = connectionUrl
        self.logger = logger

        var tls = TLSConfiguration.makeClientConfiguration()
        tls.certificateVerification = .none
        connection = try BasicConnection(connectionUrl, tls: tls, logger: logger)
    }

    func getConnection() -> Connection? {
        return connection
    }

    func run() async throws {
        logger.info("Starting up RabbitMqService...")

        // Connection monitoring & recovery pattern
        try await connection.run(reconnectionInterval: Duration.seconds(15))

        logger.info("Shutting down RabbitMqService...")
    }
}
