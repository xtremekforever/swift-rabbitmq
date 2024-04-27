
import NIO
import RabbitMq

let connection = try RabbitMq.Connection("amqp://guest:guest@localhost/%2F")

print("Connecting to RabbitMq host now...")
for _ in 0..<3 {
    print("Publishing test message...")
    _ = try await connection.reuseChannel().basicPublish(
        from: ByteBuffer(string: "{}"),
        exchange: "",
        routingKey: "test"
    )

    try await Task.sleep(for: .seconds(1))
}
print("Done!")
