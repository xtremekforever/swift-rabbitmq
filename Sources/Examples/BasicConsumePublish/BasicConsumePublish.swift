import Logging
import NIO
import RabbitMq

// Create connection and connect to the broker
let connection = try RabbitMq.Connection("amqp://guest:guest@localhost/%2F")
try await connection.connect()

// Exchange options are shared between consumer/publisher
let exchangeOptions = ExchangeOptions(
    durable: true,
    autoDelete: true
)

// Create consumer and start consuming
print("Starting test Consumer...")
let consumer = RabbitMq.Consumer(
    connection,
    "MyTestQueue",
    "MyTestExchange",
    exchangeOptions: exchangeOptions,
    queueOptions: .init(autoDelete: true, durable: true)
)
let stream = try await consumer.consume()
let consumeTask = Task {
    for try await message in stream {
        print("Consumed message: \(message)")
    }
}

// Create publisher and start publishing
print("Starting test Publisher...")
let publisher = RabbitMq.Publisher(
    connection,
    "MyTestExchange",
    exchangeOptions: exchangeOptions
)
while !Task.isCancelled {
    print("Publishing test message...")
    try await publisher.publish("A message")

    try await Task.sleep(for: .seconds(1))
}

print("Done!")

// Cleanup
consumeTask.cancel()
try await connection.close()
