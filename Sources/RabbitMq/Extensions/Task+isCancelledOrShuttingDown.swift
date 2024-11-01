extension Task where Success == Never, Failure == Never {
    /// Utility function to determine if a `Task` `isCancelled` or `isShuttingDownGracefully`.
    ///
    /// This can be used as follows:
    /// ```swift
    /// while !Task.isCancelledOrShuttingDown {
    ///     // do work
    /// }
    /// ```
    public static var isCancelledOrShuttingDown: Bool {
        Task.isCancelled || Task.isShuttingDownGracefully
    }
}
