
import NIO
import RabbitMq

let connection = try RabbitMq.Connection("amqp://guest:guest@localhost/%2F")

// Exchange options are shared between consumer/publisher
let exchangeOptions = ExchangeOptions(
    durable: true,
    autoDelete: true
)

print("Starting test Consumer...")
let consumer = RabbitMq.Consumer(connection,
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

print("Starting test Publisher...")
let publisher = RabbitMq.Publisher(connection,
    "MyTestExchange",
    exchangeOptions: exchangeOptions
)
for _ in 0..<4 {
    print("Publishing test message...")
    try await publisher.publish("A message")

    try await Task.sleep(for: .seconds(1))
}

print("Done!")

// Cleanup
consumeTask.cancel()
try await connection.close()
