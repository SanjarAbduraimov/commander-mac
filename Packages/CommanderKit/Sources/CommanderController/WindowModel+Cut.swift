import CommanderCore
import Foundation

extension WindowModel {
    public func isCut(_ item: FileItem) -> Bool {
        !cutNamesByFolder.isEmpty && cutNames(in: item.url.deletingLastPathComponent()).contains(item.name)
    }

    /// Names cut from `folder`. Kept per folder so a render checks one folder, not every item's path.
    public func cutNames(in folder: URL) -> Set<String> {
        guard !cutNamesByFolder.isEmpty else { return [] }
        return cutNamesByFolder[folder.standardizedFileURL.path] ?? []
    }

    func setCut(_ urls: [URL]) {
        let grouped = Dictionary(grouping: urls) { $0.deletingLastPathComponent().standardizedFileURL.path }
            .mapValues { Set($0.map(\.lastPathComponent)) }
        guard grouped != cutNamesByFolder else { return }
        cutNamesByFolder = grouped
        effects.stateDidChange(.pane(.left))
        effects.stateDidChange(.pane(.right))
    }

    /// Another app may have replaced the clipboard while we were in the background.
    func refreshCut() {
        guard !cutNamesByFolder.isEmpty, pasteboard.readFiles()?.isCut != true else { return }
        setCut([])
    }
}
