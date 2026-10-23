import CommanderCore
import CommanderFileSystem
import Foundation

public struct DestinationRequest: Equatable, Sendable {
    public let kind: OperationKind
    public let count: Int
    public let suggested: URL
    public let recent: [URL]
    /// Every tab folder of both panes, without repeats and without the folder the items come from.
    public let tabs: [URL]
    public let favorites: [URL]

    public init(kind: OperationKind, count: Int, suggested: URL, recent: [URL], tabs: [URL], favorites: [URL]) {
        self.kind = kind
        self.count = count
        self.suggested = suggested
        self.recent = recent
        self.tabs = tabs
        self.favorites = favorites
    }
}

extension WindowModel {
    public func createFolder(in directory: URL) async throws -> URL {
        try await environment.listingExecutor.run { try FileActions.createFolder(in: directory) }
    }

    public func createDirectory(at url: URL) async throws {
        try await environment.listingExecutor.run {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    /// Folders whose name starts with the last path component of `text` (case-insensitive), as full paths.
    public func folderSuggestions(for text: String) -> [String] {
        let expanded = (text as NSString).expandingTildeInPath
        guard expanded.hasPrefix("/") else { return [] }
        let parent = expanded.hasSuffix("/") ? expanded : (expanded as NSString).deletingLastPathComponent
        let prefix = expanded.hasSuffix("/") ? "" : (expanded as NSString).lastPathComponent
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: parent) else { return [] }
        let matches = names.filter { name in
            guard prefix.hasPrefix(".") || !name.hasPrefix(".") else { return false }
            guard name.lowercased().hasPrefix(prefix.lowercased()) else { return false }
            var isDirectory: ObjCBool = false
            return FileManager.default.fileExists(atPath: (parent as NSString).appendingPathComponent(name), isDirectory: &isDirectory)
                && isDirectory.boolValue
        }
        return matches.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            .prefix(10)
            .map { (parent as NSString).appendingPathComponent($0) }
    }

    /// The other pane, or with one pane the latest destination (else the current folder).
    func suggestedDestination(from side: PaneSide) -> URL {
        if isSinglePane { return session.recentDestinations.first ?? tab(side).path }
        return tab(side == .left ? .right : .left).path
    }

    func chooseDestination(_ kind: OperationKind, from side: PaneSide, suggested: URL) {
        let sources = tab(side).targets.map(\.url)
        guard !sources.isEmpty else {
            effects.beep()
            return
        }
        let request = destinationRequest(kind, count: sources.count, from: side, suggested: suggested)
        track {
            guard let destination = await self.effects.chooseDestination(request) else { return }
            let target = destination.standardizedFileURL.pathComponents
            if sources.contains(where: { target.starts(with: $0.standardizedFileURL.pathComponents) }) {
                self.effects.beep()
                return
            }
            self.session.addRecentDestination(destination)
            self.startTransfer(kind, sources: sources, destination: destination, from: side)
        }
    }

    private func destinationRequest(_ kind: OperationKind, count: Int, from side: PaneSide, suggested: URL) -> DestinationRequest {
        let source = tab(side).path
        var tabs: [URL] = []
        for pane in [state.left, state.right] {
            for tab in pane.tabs where !samePath(tab.path, source) && !tabs.contains(where: { samePath($0, tab.path) }) {
                tabs.append(tab.path)
            }
        }
        return DestinationRequest(
            kind: kind, count: count, suggested: suggested, recent: session.recentDestinations,
            tabs: tabs, favorites: sidebar.favorites
        )
    }
}
