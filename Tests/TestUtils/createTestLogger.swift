import Logging

public func createTestLogger(logLevel: Logger.Level? = nil, fileID: String = #fileID, line: Int = #line) -> Logger {
    if let logLevel {
        var logger = Logger(label: "testLogger(\(fileID):\(line))")
        logger.logLevel = logLevel
        return logger
    } else {
        let logger = Logger(label: "", factory: { _ in NullLogHandler() })
        return logger
    }
}
