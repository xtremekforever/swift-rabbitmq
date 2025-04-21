import Logging

/// Internal protocol for something that can log using a connection.
protocol ConnectionLoggable: Sendable {
    var logger: Logger { get async }
}
