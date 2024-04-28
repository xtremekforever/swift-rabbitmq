
import NIO
import RabbitMq

let connection = try RabbitMq.Connection("amqp://guest:guest@localhost/%2F")
defer {
    connection.close()
}
)

print("Connecting to RabbitMq host now...")
for _ in 0..<3 {
    print("Publishing test message...")
    try await publisher.publish("A message")

    try await Task.sleep(for: .seconds(1))
}
print("Done!")
