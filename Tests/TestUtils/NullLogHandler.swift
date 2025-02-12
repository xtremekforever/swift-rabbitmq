import Logging

/// LogHandler with no effect
///
public struct NullLogHandler: LogHandler {
    public init() {}

    public func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata: Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {}

    public var metadataProvider: Logger.MetadataProvider? = nil
    public var metadata = Logger.Metadata()
    public var logLevel = Logger.Level.trace

    public subscript(metadataKey _: String) -> Logger.Metadata.Value? {
        get {
            return nil
        }
        set {
            return
        }
    }
}
