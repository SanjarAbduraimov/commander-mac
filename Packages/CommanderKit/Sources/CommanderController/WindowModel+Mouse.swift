import CommanderCore

public struct MenuEntry: Equatable, Sendable {
    public let command: Command
    public let title: String
    public let shortcut: String?
    public let scope: CommandScope
}

public enum MenuItemModel: Equatable, Sendable {
    case entry(MenuEntry)
    case separator
}

public enum SlowClick {
    /// A second single click on the cursor's name, after a pause longer than a double click, starts a rename
    /// (the App waits out `NSEvent.doubleClickInterval` before acting on `true`).
    public static func shouldBeginRename(
        row name: String, clickCount: Int, cursorBefore: String?, paneWasActive: Bool, onNameText: Bool, modifiers: KeyChord.Modifiers
    ) -> Bool {
        clickCount == 1 && paneWasActive && cursorBefore == name && onNameText && modifiers.isEmpty
    }
}

extension WindowModel {
    public func click(_ side: PaneSide, row name: String?, modifiers: KeyChord.Modifiers) {
        activate(side)
        guard let name else { return }
        if modifiers.contains(.shift) {
            mutateTab(side) { $0.markRange(toName: name) }
        } else if modifiers.contains(.command) {
            mutateTab(side) { tab in
                tab.toggleMark(name: name)
                tab.setCursor(name: name)
            }
        } else {
            mutateTab(side) { $0.setCursor(name: name) }
        }
    }

    public func doubleClick(_ side: PaneSide, row name: String) {
        activate(side)
        mutateTab(side) { $0.setCursor(name: name) }
        perform(.open)
    }

    public func sortColumnClicked(_ side: PaneSide, _ column: SortColumn) {
        let current = tab(side).sort
        let sort = current.column == column ? FileSort(column: column, ascending: !current.ascending) : FileSort(column: column)
        mutateTab(side) { $0.setSort(sort) }
    }

    /// Right-click on a marked row keeps the marks (the menu acts on all of them); on any other row the cursor
    /// moves there first, so the menu acts on that row alone.
    public func contextMenu(_ side: PaneSide, row name: String?) -> [MenuItemModel] {
        activate(side)
        guard let name else { return emptySpaceMenu(side) }
        if !tab(side).marked.contains(name) {
            mutateTab(side) { $0.setCursor(name: name) }
        }
        let targets = tab(side).targets
        let packageEntry: [MenuItemModel] = targets.count == 1 && targets[0].kind == .package ? [entry(.showPackageContents)] : []
        let sizeEntry: [MenuItemModel] = isEnabled(.calculateSize, context: .table) ? [entry(.calculateSize)] : []
        return [
            entry(.open), .separator,
            entry(.copyToOtherPane), entry(.moveToOtherPane), entry(.copyTo), entry(.moveTo), .separator,
            entry(.rename), entry(.multiRename), entry(.duplicate), entry(.moveToTrash), entry(.deleteImmediately), .separator,
            entry(.copyPath), entry(.copyName),
        ] + sizeEntry + [.separator] + packageEntry + [entry(.revealInFinder), entry(.openInTerminal)]
    }

    private func emptySpaceMenu(_ side: PaneSide) -> [MenuItemModel] {
        let pasteEntry: [MenuItemModel] = isEnabled(.paste, context: .table) ? [entry(.paste)] : []
        let hiddenTitle = tab(side).showHidden ? "Hide Hidden Files" : "Show Hidden Files"
        return [entry(.newFolder)] + pasteEntry + [
            entry(.toggleHiddenFiles, title: hiddenTitle), .separator,
            entry(.openInTerminal, scope: .folder),
        ]
    }

    private func entry(_ command: Command, title: String? = nil, scope: CommandScope = .targets) -> MenuItemModel {
        .entry(MenuEntry(
            command: command,
            title: title ?? command.title,
            shortcut: bindings.chords(for: command).first?.displayString,
            scope: scope
        ))
    }
}
