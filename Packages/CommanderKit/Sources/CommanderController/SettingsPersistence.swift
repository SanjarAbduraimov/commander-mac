import CommanderCore
import os
import Synchronization

public final class SettingsPersistence: Sendable {
    private static let logger = Logger(subsystem: "local.sanjar.commander", category: "settings")

    private let store: SettingsStore
    private let writer: DebouncedWriter
    private let pending = Mutex<(settings: AppSettings?, session: Session?)>((nil, nil))

    public init(store: SettingsStore, interval: Duration = .milliseconds(500)) {
        self.store = store
        writer = DebouncedWriter(interval: interval)
    }

    public func update(_ settings: AppSettings) {
        pending.withLock { $0.settings = settings }
        scheduleWrite()
    }

    public func update(_ session: Session) {
        pending.withLock { $0.session = session }
        scheduleWrite()
    }

    /// For `applicationWillTerminate`: writes whatever is still waiting, on the calling thread.
    public func flushSynchronously() {
        writePending()
    }

    private func scheduleWrite() {
        Task { [writer] in await writer.schedule { self.writePending() } }
    }

    /// The lock is held until the files are written, so a debounced write and a flush can never interleave
    /// and an older snapshot can never land after a newer one.
    private func writePending() {
        pending.withLock { snapshots in
            if let settings = snapshots.settings {
                do { try store.save(settings) } catch { Self.logger.error("Saving settings failed: \(error.localizedDescription)") }
            }
            if let session = snapshots.session {
                do { try store.save(session) } catch { Self.logger.error("Saving session failed: \(error.localizedDescription)") }
            }
            snapshots = (nil, nil)
        }
    }
}
