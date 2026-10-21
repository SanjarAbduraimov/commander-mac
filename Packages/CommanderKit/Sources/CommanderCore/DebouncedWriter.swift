public actor DebouncedWriter {
    private let interval: Duration
    private var pendingWork: (@Sendable () -> Void)?
    private var timer: Task<Void, Never>?

    public init(interval: Duration = .milliseconds(500)) {
        self.interval = interval
    }

    public func schedule(_ work: @escaping @Sendable () -> Void) {
        pendingWork = work
        timer?.cancel()
        timer = Task { [interval] in
            try? await Task.sleep(for: interval)
            guard !Task.isCancelled else { return }
            self.runPending()
        }
    }

    public func flush() {
        timer?.cancel()
        runPending()
    }

    private func runPending() {
        let work = pendingWork
        pendingWork = nil
        work?()
    }
}
