import NIO
import RabbitMq

// Create connection and connect to the broker
let connection = BasicConnection("amqp://guest:guest@localhost/%2F")
try await connection.connect()

// Use structured task group to run examples
try await withThrowingDiscardingTaskGroup { group in

    // Exchange options are shared between consumer and publisher
    let exchangeOptions = ExchangeOptions(
        durable: true,
        autoDelete: true
    )

    // Create consumer and start consuming
    group.addTask {
        print("Starting test Consumer...")
        let consumer = Consumer(
            connection,
            "MyTestQueue",
            "MyTestExchange",
            exchangeOptions: exchangeOptions,
            queueOptions: .init(autoDelete: true, durable: true)
        )
        for await message in try await consumer.consume() {
            print("Consumed message: \(message)")
        }
    }

    // Create publisher and start publishing
    group.addTask {
        print("Starting test Publisher...")
        let publisher = Publisher(
            connection,
            "MyTestExchange",
            exchangeOptions: exchangeOptions
        )
        while !Task.isCancelled {
            print("Publishing test message...")
            try await publisher.publish("A message")

            try await Task.sleep(for: .seconds(1))
        }
    }
}

print("Done!")

// Cleanup
await connection.close()
