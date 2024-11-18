import AMQPClient
import Foundation
import NIOCore
import NIOSSL

extension AMQPConnectionConfiguration.UrlScheme {
    var defaultPort: Int {
        switch self {
        case .amqp: return 5672
        case .amqps: return 5671
        }
    }
}

extension AMQPConnectionConfiguration {
    init(url: String, tls: TLSConfiguration? = nil, timeout: TimeAmount, connectionName: String) throws {
        guard let url = URL(string: url) else { throw AMQPConnectionError.invalidUrl }
        guard let scheme = UrlScheme(rawValue: url.scheme ?? "") else { throw AMQPConnectionError.invalidUrlScheme }

        // there is no such thing as a "" host
        let host = url.host?.isEmpty == true ? nil : url.host
        //special path magic for vhost interpretation (see https://www.rabbitmq.com/uri-spec.html)
        var vhost = url.path.isEmpty ? nil : String(url.path.removingPercentEncoding?.dropFirst() ?? "")

        // workaround: "/%f" is interpreted as / by URL (this restores %f as /)
        if url.absoluteString.lowercased().hasSuffix("%2f") {
            vhost = "/"
        }

        let server = Server(
            host: host, port: url.port ?? scheme.defaultPort, user: url.user,
            password: url.password?.removingPercentEncoding, vhost: vhost,
            timeout: timeout, connectionName: connectionName
        )

        switch scheme {
        case .amqp: self = .init(connection: .plain, server: server)
        case .amqps: self = .init(connection: .tls(tls, sniServerName: nil), server: server)
        }
    }
}
