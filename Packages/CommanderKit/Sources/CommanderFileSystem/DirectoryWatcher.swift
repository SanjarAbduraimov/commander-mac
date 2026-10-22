import CoreServices
import Foundation
import Synchronization

public final class DirectoryWatcher: Sendable {
    /// Owned by the FSEvents stream (retained in its context) so callbacks never outlive their target.
    private final class Context: Sendable {
        let directoryPath: String
        let onChange: @Sendable () -> Void

        init(directoryPath: String, onChange: @escaping @Sendable () -> Void) {
            self.directoryPath = directoryPath
            self.onChange = onChange
        }

        func handle(_ paths: [String]) {
            let relevant = paths.contains { path in
                let trimmed = path.hasSuffix("/") ? String(path.dropLast()) : path
                return trimmed == directoryPath || (trimmed as NSString).deletingLastPathComponent == directoryPath
            }
            if relevant { onChange() }
        }
    }

    private struct StreamBox: @unchecked Sendable {
        let stream: FSEventStreamRef
    }

    private let context: Context
    private let latency: Duration
    private let queue = DispatchQueue(label: "CommanderFileSystem.DirectoryWatcher")
    private let stream = Mutex<StreamBox?>(nil)

    public init(directory: URL, latency: Duration = .milliseconds(150), onChange: @escaping @Sendable () -> Void) {
        self.context = Context(directoryPath: Self.canonicalPath(directory), onChange: onChange)
        self.latency = latency
    }

    deinit {
        stop()
    }

    public func start() {
        stream.withLock { box in
            guard box == nil else { return }
            var streamContext = FSEventStreamContext(
                version: 0,
                info: Unmanaged.passRetained(context).toOpaque(),
                retain: nil,
                release: { info in
                    if let info { Unmanaged<Context>.fromOpaque(info).release() }
                },
                copyDescription: nil
            )
            let callback: FSEventStreamCallback = { _, info, count, eventPaths, _, _ in
                guard let info else { return }
                let paths = unsafeBitCast(eventPaths, to: NSArray.self) as? [String] ?? []
                Unmanaged<Context>.fromOpaque(info).takeUnretainedValue().handle(Array(paths.prefix(count)))
            }
            let flags = FSEventStreamCreateFlags(
                kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents
                    | kFSEventStreamCreateFlagNoDefer | kFSEventStreamCreateFlagWatchRoot)
            guard let created = FSEventStreamCreate(
                kCFAllocatorDefault, callback, &streamContext, [context.directoryPath] as CFArray,
                FSEventStreamEventId(kFSEventStreamEventIdSinceNow), Self.seconds(latency), flags)
            else { return }
            FSEventStreamSetDispatchQueue(created, queue)
            FSEventStreamStart(created)
            box = StreamBox(stream: created)
        }
    }

    public func stop() {
        stream.withLock { box in
            guard let current = box?.stream else { return }
            FSEventStreamStop(current)
            FSEventStreamInvalidate(current)
            FSEventStreamRelease(current)
            box = nil
        }
    }

    /// FSEvents reports real paths (e.g. /private/var/...), so compare against the realpath.
    private static func canonicalPath(_ url: URL) -> String {
        guard let resolved = realpath(url.path, nil) else { return url.standardizedFileURL.path }
        defer { free(resolved) }
        return String(cString: resolved)
    }

    private static func seconds(_ duration: Duration) -> CFTimeInterval {
        let parts = duration.components
        return Double(parts.seconds) + Double(parts.attoseconds) / 1e18
    }
}
