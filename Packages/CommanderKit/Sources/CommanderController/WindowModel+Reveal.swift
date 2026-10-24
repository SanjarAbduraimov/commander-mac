import Foundation

extension WindowModel {
    /// "Reveal in Commander" from Finder, the Dock or `open -a`: a new tab in the active pane shows the folder,
    /// or a file's (or package's) folder with the cursor on it.
    public func reveal(_ url: URL) {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            effects.beep()
            return
        }
        let isPackage = (try? url.resourceValues(forKeys: [.isPackageKey]).isPackage) == true
        let side = state.activeSide
        mutatePane(side) { $0.newTab() }
        if isDirectory.boolValue, !isPackage {
            navigate(side, to: url.standardizedFileURL)
        } else {
            navigate(side, to: url.deletingLastPathComponent().standardizedFileURL)
            pendingCursor[side] = url.lastPathComponent
        }
    }
}
