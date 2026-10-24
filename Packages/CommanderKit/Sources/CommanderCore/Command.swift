public enum Command: String, CaseIterable, Codable, Sendable {
    case moveUp, moveDown, moveToStart, moveToEnd, pageUp, pageDown
    case markUp, markDown, toggleMark, markAll
    case open, goUp, goBack, goForward
    case switchPane, newTab, closeTab, nextTab, previousTab
    case focusPathField, reload, toggleHiddenFiles
    case copyToClipboard, cutToClipboard, paste, duplicate
    case copyToOtherPane, moveToOtherPane, newFolder, rename, moveToTrash
    case connectToServer, openSettings
    case copyPath, copyName, showPackageContents, revealInFinder, openInTerminal
    case unmarkAll, copyTo, moveTo, deleteImmediately, calculateSize, toggleSinglePane
    case multiRename, undoMultiRename

    /// While a text field has focus, keys edit text; only these window-level commands still fire.
    public var isAllowedInTextField: Bool {
        switch self {
        case .openSettings, .connectToServer, .newTab, .closeTab, .nextTab, .previousTab, .focusPathField, .toggleSinglePane: true
        default: false
        }
    }
}
