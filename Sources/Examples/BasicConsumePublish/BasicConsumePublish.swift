import ArgumentParser
import Logging
import NIO
import RabbitMq

@main
struct BasicConsumePublish: AsyncParsableCommand {
    @Option
    var rabbitUrl: String = "amqp://guest:guest@localhost/%2F"

    @Option
    var logLevel: String = "info"

    @Option(help: "The interval at which to publish the test message in milliseconds.")
    var publishInterval: Int = 1000

    // Customizable log level
    func createLogger() -> Logger {
        var logger = Logger(label: String(describing: Self.self))
        logger.logLevel = Logger.Level(rawValue: logLevel) ?? .info
        return logger
    }

    mutating func run() async throws {
        let logger = createLogger()

        // Create connection and connect to the broker
        let connection = BasicConnection(rabbitUrl, logger: logger)
        try await connection.connect()

        // Use structured task group to run examples
        try await withThrowingDiscardingTaskGroup { group in
            // Exchange options are shared between consumer and publisher
            let exchangeOptions = ExchangeOptions(
                durable: true,
                autoDelete: true
            )

            let publishInterval = self.publishInterval

            // Create consumer and start consuming
            group.addTask {
                logger.info("Starting test Consumer...")
                let consumer = Consumer(
                    connection,
                    "MyTestQueue",
                    "MyTestExchange",
                    exchangeOptions: exchangeOptions,
                    queueOptions: .init(autoDelete: true, durable: true)
                )
                for await message in try await consumer.consume() {
                    logger.info("Consumed message: \(message)")
                }
            }

            // Create publisher and start publishing
            group.addTask {
                logger.info("Starting test Publisher...")
                let publisher = Publisher(
                    connection,
                    "MyTestExchange",
                    exchangeOptions: exchangeOptions
                )
                while !Task.isCancelled {
                    logger.info("Publishing test message...")
                    try await publisher.publish("A message")

                    try await Task.sleep(for: .milliseconds(publishInterval))
                }
            }
        }

        logger.info("Done!")

        // Cleanup
        await connection.close()
    }
}
