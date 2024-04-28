
import AMQPClient
import Foundation
import NIO

final public class Connection: Sendable {
    private let config: AMQPConnectionConfiguration
    private let eventLoop: EventLoop

    private var channel: AMQPChannel?
    private var connection: AMQPConnection?

    public init(eventLoop: EventLoop = MultiThreadedEventLoopGroup(numberOfThreads: 1).next(),
                _ url: String = "") throws {
        self.eventLoop = eventLoop
        self.config = try AMQPConnectionConfiguration.init(url: url)

        // TODO: Support TLS configuration
    }

    public func reuseChannel() async throws -> AMQPChannel {
        guard let channel = self.channel, channel.isOpen else {
            if self.connection == nil || self.connection!.isConnected {
                self.connection = try await AMQPConnection.connect(use: self.eventLoop, from: self.config)
            }

            self.channel = try await connection!.openChannel()
            return self.channel!
        }
        return channel
    }

    public func close() {
        channel?.close()
        _ = connection?.close()
    }
}
