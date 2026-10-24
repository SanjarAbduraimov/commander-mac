import CommanderCore
import CommanderFileSystem
import Foundation

/// Path-field edits of the Copy To folder browser.
public enum PathText {
    public static func enter(_ folder: String) -> String {
        folder.hasSuffix("/") ? folder : folder + "/"
    }

    /// The folder above the one the text names; "/" stays "/".
    public static func parent(of text: String) -> String {
        let trimmed = text.count > 1 && text.hasSuffix("/") ? String(text.dropLast()) : text
        let parent = (trimmed as NSString).deletingLastPathComponent
        return parent.isEmpty || parent == "/" ? "/" : parent + "/"
    }
}

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
    /// Read on the listing executor: the folder may be on a slow or dead network share.
    /// `limit: nil` lists every match (the Copy To folder browser).
    public func folderSuggestions(for text: String, limit: Int? = 10) async -> [String] {
        (try? await environment.listingExecutor.run { Self.folderSuggestions(for: text, limit: limit) }) ?? []
    }

    nonisolated static func folderSuggestions(for text: String, limit: Int?) -> [String] {
        // expandingTildeInPath drops a trailing "/", which is what says "list inside this folder".
        let expanded = (text as NSString).expandingTildeInPath
        guard expanded.hasPrefix("/") else { return [] }
        let insideFolder = text.hasSuffix("/")
        let parent = insideFolder ? expanded : (expanded as NSString).deletingLastPathComponent
        let prefix = insideFolder ? "" : (expanded as NSString).lastPathComponent
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: parent) else { return [] }
        let candidates = names
            .filter { (prefix.hasPrefix(".") || !$0.hasPrefix(".")) && $0.lowercased().hasPrefix(prefix.lowercased()) }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        var folders: [String] = []
        // Stat only until enough folders are found, not every entry of a large folder.
        for name in candidates where folders.count < (limit ?? .max) {
            let path = (parent as NSString).appendingPathComponent(name)
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue { folders.append(path) }
        }
        return folders
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
            let intoSource = sources.contains { target.starts(with: $0.standardizedFileURL.pathComponents) }
            // Moving items into the folder they are already in would only raise a conflict with themselves.
            let alreadyThere = kind == .move
                && sources.allSatisfy { $0.deletingLastPathComponent().standardizedFileURL.pathComponents == target }
            if intoSource || alreadyThere {
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
