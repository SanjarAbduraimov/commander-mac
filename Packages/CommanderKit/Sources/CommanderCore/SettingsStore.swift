import Foundation

public struct LoadResult<Value: Sendable>: Sendable {
    public let value: Value
    /// Where an unreadable file was moved aside; the UI warns the user once when this is set.
    public let corruptFileBackup: URL?
}

public struct SettingsStore: Sendable {
    typealias Migration = @Sendable (inout [String: Any]) -> Void

    public static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Commander", isDirectory: true)
    }

    private let directory: URL
    private let settingsMigrations: [Int: Migration]
    private let sessionMigrations: [Int: Migration]

    public init(directory: URL) {
        self.init(directory: directory, settingsMigrations: [:])
    }

    init(directory: URL, settingsMigrations: [Int: Migration], sessionMigrations: [Int: Migration] = [:]) {
        self.directory = directory
        self.settingsMigrations = settingsMigrations
        self.sessionMigrations = sessionMigrations
    }

    public func loadSettings() -> LoadResult<AppSettings> {
        load(file: "settings", default: AppSettings(), currentVersion: AppSettings.currentVersion, migrations: settingsMigrations)
    }

    public func loadSession() -> LoadResult<Session> {
        load(file: "session", default: Session(), currentVersion: Session.currentVersion, migrations: sessionMigrations)
    }

    public func save(_ settings: AppSettings) throws {
        try write(settings, file: "settings")
    }

    public func save(_ session: Session) throws {
        try write(session, file: "session")
    }

    private func url(for file: String) -> URL {
        directory.appendingPathComponent("\(file).json")
    }

    private func write(_ value: some Encodable, file: String) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(value).write(to: url(for: file), options: .atomic)
    }

    private func load<T: Decodable & Sendable>(file: String, default defaultValue: T, currentVersion: Int, migrations: [Int: Migration]) -> LoadResult<T> {
        let fileURL = url(for: file)
        guard let data = try? Data(contentsOf: fileURL) else {
            return LoadResult(value: defaultValue, corruptFileBackup: nil)
        }
        do {
            guard var object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw CocoaError(.fileReadCorruptFile)
            }
            var version = object["version"] as? Int ?? currentVersion
            while version < currentVersion {
                migrations[version]?(&object)
                version += 1
            }
            object["version"] = version
            let migrated = try JSONSerialization.data(withJSONObject: object)
            return LoadResult(value: try JSONDecoder().decode(T.self, from: migrated), corruptFileBackup: nil)
        } catch {
            return LoadResult(value: defaultValue, corruptFileBackup: moveAside(fileURL, file: file))
        }
    }

    private func moveAside(_ fileURL: URL, file: String) -> URL? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let backup = directory.appendingPathComponent("\(file).broken-\(formatter.string(from: Date())).json")
        do {
            try FileManager.default.moveItem(at: fileURL, to: backup)
            return backup
        } catch {
            return nil
        }
    }
}
