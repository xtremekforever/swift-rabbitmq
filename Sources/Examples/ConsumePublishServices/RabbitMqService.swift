import Logging
import NIOSSL
import RabbitMq
import ServiceLifecycle

// Service that creates RabbitMq connection & monitors it until shutdown
struct RabbitMqService: Service, Connectable {
    private let connectionUrl: String
    private let logger: Logger
    private let connection: Connection

    init(
        _ connectionUrl: String,
        _ logger: Logger = Logger(label: String(describing: RabbitMqService.self))
    ) throws {
        self.connectionUrl = connectionUrl
        self.logger = logger

        var tls = TLSConfiguration.makeClientConfiguration()
        tls.certificateVerification = .none
        connection = try Connection(connectionUrl, tls: tls, logger: logger)
    }

    func getConnection() -> Connection? {
        return connection
    }

    func run() async throws {
        logger.info("Starting up RabbitMqService...")

        // Connection monitoring & recovery pattern
        do {
            try await cancelWhenGracefulShutdown {
                try await connection.retryingConnect(reconnectionInterval: .seconds(15))
            }
        } catch (_ as CancellationError) {
            // ignore CancellationError...
        }

        logger.info("Shutting down RabbitMqService...")
    }
}
