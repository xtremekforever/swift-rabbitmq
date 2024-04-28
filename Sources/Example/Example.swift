
import NIO
import RabbitMq

let connection = try RabbitMq.Connection("amqp://guest:guest@localhost/%2F")

let exchangeOptions = ExchangeOptions(
    declare: true,
    name: "MyTestExchange",
    durable: true,
    autoDelete: true
)

print("Consuming messages now...")
let consumer = RabbitMq.Consumer(connection, "MyTestQueue", 
    consumerOptions: .init(
        exchangeOptions: exchangeOptions,
        queueOptions: .init(declare: true, autoDelete: true, durable: true)
    )
)
let stream = try await consumer.consume()
let consumeTask = Task {
    for try await message in stream {
        print("Consumed message: \(message)")
    }
}

print("Starting Publisher now...")
let publisher = RabbitMq.Publisher(connection,
    exchangeOptions: exchangeOptions
)
for _ in 0..<4 {
    print("Publishing test message...")
    try await publisher.publish("A message")

    try await Task.sleep(for: .seconds(1))
}

print("Done!")

consumeTask.cancel()
try await connection.close()
