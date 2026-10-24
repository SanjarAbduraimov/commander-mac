import CommanderCore
import Foundation

/// `.folder` is the current folder itself (the empty-space context menu), not the marked or cursor items.
public enum CommandScope: Sendable {
    case targets, folder
}

extension WindowModel {
    private static let defaultPageSize = 20

    private static let targetCommands: Set<Command> = [
        .copyToOtherPane, .moveToOtherPane, .duplicate, .moveToTrash, .copyToClipboard, .cutToClipboard,
        .copyPath, .copyName, .revealInFinder, .deleteImmediately, .copyTo, .moveTo, .multiRename,
    ]

    public func perform(_ command: Command, scope: CommandScope = .targets) {
        let side = state.activeSide
        switch command {
        case .moveUp: mutateTab(side) { $0.moveCursor(by: -1) }
        case .moveDown: mutateTab(side) { $0.moveCursor(by: 1) }
        case .moveToStart: mutateTab(side) { $0.moveCursorToStart() }
        case .moveToEnd: mutateTab(side) { $0.moveCursorToEnd() }
        case .pageUp: mutateTab(side) { $0.moveCursor(by: -pageStep(side)) }
        case .pageDown: mutateTab(side) { $0.moveCursor(by: pageStep(side)) }
        case .markUp: mutateTab(side) { $0.moveCursorMarking(by: -1) }
        case .markDown: mutateTab(side) { $0.moveCursorMarking(by: 1) }
        case .toggleMark: mutateTab(side) { [advance = settings.behavior.spaceAdvances] in $0.toggleMark(advance: advance) }
        case .markAll: mutateTab(side) { $0.markAll() }
        case .unmarkAll: mutateTab(side) { $0.clearMarks() }
        case .open: openCursorItem(side)
        case .goUp: mutatePane(side) { $0.activeTab.goUp() }
        case .goBack: mutatePane(side) { $0.activeTab.goBack() }
        case .goForward: mutatePane(side) { $0.activeTab.goForward() }
        case .switchPane: activate(side == .left ? .right : .left)
        case .newTab: mutatePane(side) { $0.newTab() }
        case .closeTab: mutatePane(side) { $0.closeActiveTab() }
        case .nextTab: mutatePane(side) { $0.selectNextTab() }
        case .previousTab: mutatePane(side) { $0.selectPreviousTab() }
        case .focusPathField: effects.focusPathField(side)
        case .reload:
            clearSizes(side)
            reload(side)
        case .calculateSize: calculateSizes(side)
        case .toggleHiddenFiles: mutateTab(side) { $0.setShowHidden(!$0.showHidden) }
        case .openSettings: effects.showSettings()
        case .connectToServer: effects.showConnectToServer()
        case .copyToClipboard, .cutToClipboard, .paste, .duplicate, .copyToOtherPane, .moveToOtherPane,
             .newFolder, .rename, .moveToTrash, .copyPath, .copyName, .showPackageContents, .revealInFinder,
             .openInTerminal, .deleteImmediately:
            performFileCommand(command, on: side, scope: scope)
        case .copyTo: chooseDestination(.copy, from: side, suggested: suggestedDestination(from: side))
        case .moveTo: chooseDestination(.move, from: side, suggested: suggestedDestination(from: side))
        case .toggleSinglePane: toggleSinglePane()
        case .multiRename: startMultiRename(side)
        case .markByPattern, .unmarkByPattern:
            let marking = command == .markByPattern
            let request = PatternRequest(marking: marking, recent: session.recentPatterns)
            track {
                guard let text = await self.effects.askPattern(request)?.trimmingCharacters(in: .whitespaces), !text.isEmpty
                else { return }
                self.session.addRecentPattern(text)
                let pattern = NamePattern(text)
                self.mutateTab(side) { marking ? $0.mark(matching: pattern) : $0.unmark(matching: pattern) }
            }
        case .invertMarks: mutateTab(side) { $0.invertMarks() }
        case .markSameExtension: mutateTab(side) { $0.markSameExtension() }
        case .undoMultiRename:
            track {
                if let message = await self.undoMultiRename() {
                    self.effects.showAlert(AlertMessage(title: "Multi-Rename was partly undone", detail: message))
                }
            }
        }
    }

    @discardableResult
    public func handleKey(_ chord: KeyChord, context: FocusContext) -> Bool {
        guard let command = bindings.command(for: chord, in: context), isEnabled(command, context: context) else { return false }
        perform(command)
        return true
    }

    public func isEnabled(_ command: Command, context: FocusContext) -> Bool {
        if context == .textField, !command.isAllowedInTextField { return false }
        let tab = tab(state.activeSide)
        if Self.targetCommands.contains(command) { return !tab.targets.isEmpty }
        switch command {
        case .rename: return tab.cursorItem != nil
        case .switchPane: return !isSinglePane
        case .unmarkAll: return !tab.marked.isEmpty
        case .undoMultiRename: return canUndoMultiRename
        case .calculateSize: return tab.targets.contains { $0.kind == .directory || $0.kind == .package }
        case .showPackageContents: return tab.cursorItem?.kind == .package
        case .paste: return pasteboard.readFiles() != nil
        default: return true
        }
    }

    public func typeAhead(_ character: Character) {
        let side = state.activeSide
        guard let name = typeAheadInput.input(character, at: environment.now(), in: tab(side).items) else { return }
        mutateTab(side) { $0.setCursor(name: name) }
    }

    public func setPageSize(_ side: PaneSide, rows: Int) {
        pageSizes[side] = rows
    }

    @discardableResult
    public func goToPath(_ side: PaneSide, _ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let path = (trimmed as NSString).expandingTildeInPath
        var isDirectory: ObjCBool = false
        guard !trimmed.isEmpty, FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
            effects.beep()
            return false
        }
        let url = URL(fileURLWithPath: path, isDirectory: isDirectory.boolValue)
        if isDirectory.boolValue {
            navigate(side, to: url)
        } else {
            navigate(side, to: url.deletingLastPathComponent())
            pendingCursor[side] = url.lastPathComponent
        }
        return true
    }

    public func selectTab(_ side: PaneSide, at index: Int) {
        mutatePane(side) { $0.selectTab(at: index) }
    }

    public func closeTab(_ side: PaneSide, at index: Int) {
        mutatePane(side) { pane in
            pane.selectTab(at: index)
            pane.closeActiveTab()
        }
    }

    private func toggleSinglePane() {
        session.singlePane.toggle()
        if isSinglePane { activate(.left) }
        effects.stateDidChange(.window)
        publishSession()
    }

    private func pageStep(_ side: PaneSide) -> Int {
        max(pageSizes[side, default: Self.defaultPageSize] - 1, 1)
    }

    private func openCursorItem(_ side: PaneSide) {
        guard let item = tab(side).cursorItem else { return }
        if item.isNavigable {
            navigate(side, to: item.url)
        } else {
            effects.open(item.url)
        }
    }
}
