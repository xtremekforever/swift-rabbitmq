import Logging

extension Logger {
    func withMetadata(_ metadata: [String: Logger.MetadataValue]) -> Logger {
        var logger = self
        for (key, value) in metadata {
            logger[metadataKey: key] = value
        }
        return logger
    }
}
