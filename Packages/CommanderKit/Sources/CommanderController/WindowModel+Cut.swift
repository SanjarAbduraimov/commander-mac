import CommanderCore
import Foundation

extension WindowModel {
    public func isCut(_ item: FileItem) -> Bool {
        !cutPaths.isEmpty && cutPaths.contains(item.url.standardizedFileURL.path)
    }

    func setCut(_ urls: [URL]) {
        let paths = Set(urls.map(\.standardizedFileURL.path))
        guard paths != cutPaths else { return }
        cutPaths = paths
        effects.stateDidChange(.pane(.left))
        effects.stateDidChange(.pane(.right))
    }

    /// Another app may have replaced the clipboard while we were in the background.
    func refreshCut() {
        guard !cutPaths.isEmpty, pasteboard.readFiles()?.isCut != true else { return }
        setCut([])
    }
}
