extension Task where Success == Never, Failure == Never {
    public static var isCancelledOrShuttingDown: Bool {
        Task.isCancelled || Task.isShuttingDownGracefully
    }
}
