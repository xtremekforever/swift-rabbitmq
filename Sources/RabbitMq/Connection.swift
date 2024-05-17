import AMQPClient
import Foundation
import NIO
import NIOSSL

public actor Connection {
    private let config: AMQPConnectionConfiguration
    private let eventLoop: EventLoop

    private var channel: AMQPChannel?
    private var connection: AMQPConnection?

    public init(
        eventLoop: EventLoop = MultiThreadedEventLoopGroup(numberOfThreads: 1).next(),
        _ url: String = "",
        tls: TLSConfiguration = TLSConfiguration.makeClientConfiguration()
    ) throws {
        self.eventLoop = eventLoop
        self.config = try AMQPConnectionConfiguration.init(url: url, tls: tls)
    }

    public func isConnected() -> Bool {
        if let conn = self.connection {
            return conn.isConnected
        }
        return false
    }

    public func reuseChannel() async throws -> AMQPChannel {
        guard let channel = self.channel, channel.isOpen else {
            if self.connection == nil || self.connection!.isConnected {
                self.connection = try await AMQPConnection.connect(
                    use: self.eventLoop, from: self.config)
            }

            self.channel = try await connection!.openChannel()
            return self.channel!
        }
        return channel
    }

    public func close() async throws {
        try await channel?.close()
        try await connection?.close()
    }
}
