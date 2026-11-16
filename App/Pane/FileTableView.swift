import AppKit
import CommanderController
import CommanderCore

final class FileTableView: NSTableView {
    var side: PaneSide = .left
    weak var model: WindowModel?
    /// Called once a press on a row has moved far enough to be a drag (Task 15 starts the drag session).
    var onBeginDrag: ((_ row: Int, _ event: NSEvent) -> Void)?
    /// A drag left the table or ended (dropped, or cancelled with Esc).
    var onDragExit: (() -> Void)?

    private var pendingRename: Task<Void, Never>?
    private var dragStartPoint: NSPoint?
    private var dragStartRow: Int?
    private var initialMouseDownEvent: NSEvent?

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted { model?.activate(side) }
        return accepted
    }

    /// Clicks follow the spec's rules (cursor vs. marks), not NSTableView's selection, so `super` is not called.
    override func mouseDown(with event: NSEvent) {
        guard let model else { return }
        pendingRename?.cancel()
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.control) {
            if let menu = menu(for: event) { NSMenu.popUpContextMenu(menu, with: event, for: self) }
            return
        }

        let point = convert(event.locationInWindow, from: nil)
        let row = row(at: point)
        let items = model.tab(side).items
        let name = items.indices.contains(row) ? items[row].name : nil
        let paneWasActive = model.state.activeSide == side
        let cursorBefore = model.tab(side).cursor
        var modifiers: KeyChord.Modifiers = []
        if flags.contains(.command) { modifiers.insert(.command) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        if flags.contains(.option) { modifiers.insert(.option) }

        window?.makeFirstResponder(self)
        if event.clickCount >= 2, let name {
            model.doubleClick(side, row: name)
            return
        }
        model.click(side, row: name, modifiers: modifiers)
        guard let name else { return }

        if SlowClick.shouldBeginRename(
            row: name, clickCount: event.clickCount, cursorBefore: cursorBefore, paneWasActive: paneWasActive,
            onNameText: isOnNameText(point, row: row), modifiers: modifiers
        ) {
            scheduleRename(of: name)
        }
        dragStartPoint = event.locationInWindow
        dragStartRow = row
        initialMouseDownEvent = event
    }

    override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)
        guard let start = dragStartPoint, let row = dragStartRow else { return }
        let current = event.locationInWindow
        if hypot(current.x - start.x, current.y - start.y) > 3 {
            dragStartPoint = nil
            dragStartRow = nil
            pendingRename?.cancel()
            let downEvent = initialMouseDownEvent ?? event
            initialMouseDownEvent = nil
            onBeginDrag?(row, downEvent)
        }
    }

    override func mouseUp(with event: NSEvent) {
        dragStartPoint = nil
        dragStartRow = nil
        initialMouseDownEvent = nil
        super.mouseUp(with: event)
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        super.draggingExited(sender)
        onDragExit?()
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        super.draggingEnded(sender)
        onDragExit?()
    }

    override func scrollWheel(with event: NSEvent) {
        pendingRename?.cancel()
        super.scrollWheel(with: event)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        guard let model else { return nil }
        pendingRename?.cancel()
        let row = row(at: convert(event.locationInWindow, from: nil))
        let items = model.tab(side).items
        let name = items.indices.contains(row) ? items[row].name : nil
        window?.makeFirstResponder(self)

        let menu = NSMenu()
        for entry in model.contextMenu(side, row: name) {
            guard case let .entry(entry) = entry else {
                menu.addItem(.separator())
                continue
            }
            let item = NSMenuItem(title: entry.title, action: #selector(performMenuEntry(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = [entry.command.rawValue, entry.scope == .folder ? "folder" : "targets"]
            if let equivalent = model.bindings.chords(for: entry.command).lazy.compactMap(MainMenu.keyEquivalent).first {
                item.keyEquivalent = equivalent.key
                item.keyEquivalentModifierMask = equivalent.modifiers
            }
            menu.addItem(item)
        }

        menu.addItem(.separator())
        let telegramItem = NSMenuItem(title: "Telegram", action: #selector(shareToTelegramClicked), keyEquivalent: "")
        if let paperplane = NSImage(systemSymbolName: "paperplane.fill", accessibilityDescription: "Telegram") {
            telegramItem.image = paperplane.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 11, weight: .medium))
        }
        telegramItem.target = self
        menu.addItem(telegramItem)

        return menu
    }

    @objc private func shareToTelegramClicked() {
        guard let model else { return }
        let urls = model.tab(side).targets.map(\.url)
        TelegramSharing.share(urls: urls, from: self)
    }

    @objc private func performMenuEntry(_ sender: NSMenuItem) {
        guard let parts = sender.representedObject as? [String], let command = Command(rawValue: parts[0]) else { return }
        model?.perform(command, scope: parts[1] == "folder" ? .folder : .targets)
    }

    // Edit-menu clicks while the table has focus; keystrokes already went through KeyRouter.
    @objc func copy(_ sender: Any?) { model?.perform(.copyToClipboard) }
    @objc func cut(_ sender: Any?) { model?.perform(.cutToClipboard) }
    @objc func paste(_ sender: Any?) { model?.perform(.paste) }
    @objc func undo(_ sender: Any?) { model?.perform(.undo) }
    @objc func redo(_ sender: Any?) { model?.perform(.redo) }
    override func selectAll(_ sender: Any?) { model?.perform(.markAll) }

    override func validateUserInterfaceItem(_ item: any NSValidatedUserInterfaceItem) -> Bool {
        guard let model else { return false }
        switch item.action {
        case #selector(copy(_:)): return model.isEnabled(.copyToClipboard, context: .table)
        case #selector(cut(_:)): return model.isEnabled(.cutToClipboard, context: .table)
        case #selector(paste(_:)): return model.isEnabled(.paste, context: .table)
        case #selector(selectAll(_:)): return true
        case #selector(undo(_:)): return model.isEnabled(.undo, context: .table)
        case #selector(redo(_:)): return model.isEnabled(.redo, context: .table)
        default: return super.validateUserInterfaceItem(item)
        }
    }

    private func isOnNameText(_ point: NSPoint, row: Int) -> Bool {
        let column = column(withIdentifier: NSUserInterfaceItemIdentifier(FileTableController.Column.name.rawValue))
        guard let cell = view(atColumn: column, row: row, makeIfNecessary: false) as? NSTableCellView,
              let text = cell.textField
        else { return false }
        let textRect = text.convert(text.bounds, to: self)
        let usedWidth = min(text.attributedStringValue.size().width + 4, textRect.width)
        return NSRect(x: textRect.minX, y: textRect.minY, width: usedWidth, height: textRect.height).contains(point)
    }

    /// A second click on the cursor's name starts rename only if no double click follows within the system interval.
    private func scheduleRename(of name: String) {
        let interval = NSEvent.doubleClickInterval
        pendingRename = Task { [weak self] in
            try? await Task.sleep(for: .seconds(interval))
            guard !Task.isCancelled, let self, let model = self.model,
                  model.state.activeSide == self.side, model.tab(self.side).cursor == name
            else { return }
            model.perform(.rename)
        }
    }

    func autoFitColumn(at columnIndex: Int) {
        guard tableColumns.indices.contains(columnIndex) else { return }
        let column = tableColumns[columnIndex]
        guard let colID = FileTableController.Column(rawValue: column.identifier.rawValue), colID != .mark else { return }

        guard let model else { return }
        let tab = model.tab(side)
        let items = tab.items
        let appearance = model.settings.appearance
        let font = appearance.fontName.flatMap { NSFont(name: $0, size: appearance.fontSize) } ?? .systemFont(ofSize: appearance.fontSize)

        // 1. Header title width + sort indicator & margin space
        let headerFont = NSFont.systemFont(ofSize: 11, weight: .bold)
        let titleWidth = (column.title as NSString).size(withAttributes: [.font: headerFont]).width + 28

        // 2. Measure visible & sampled items
        var maxContentWidth: CGFloat = 0
        let sample = items.prefix(250)

        for item in sample {
            let str: String
            switch colID {
            case .mark:
                str = ""
            case .name:
                let showsExt = appearance.columns.contains { $0.id == .ext }
                str = showsExt ? item.baseName : item.name
            case .ext:
                str = item.ext
            case .size:
                let size = item.size ?? model.folderSize(side, item)
                str = size.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? "--"
            case .modified:
                str = item.modified.formatted(Date.FormatStyle(date: .numeric, time: .shortened))
            case .created:
                str = item.created?.formatted(Date.FormatStyle(date: .numeric, time: .shortened)) ?? "--"
            case .kind:
                str = item.kindName
            }

            let textWidth = (str as NSString).size(withAttributes: [.font: font]).width
            var rowWidth = textWidth + 16
            if colID == .name {
                rowWidth += CGFloat(appearance.iconSize) + 8
            }
            if rowWidth > maxContentWidth {
                maxContentWidth = rowWidth
            }
        }

        let minWidth: CGFloat = colID == .ext ? 45 : (colID == .name ? 120 : 65)
        let maxWidth: CGFloat = colID == .name ? 800 : 350
        let idealWidth = min(max(max(titleWidth, maxContentWidth), minWidth), maxWidth)

        column.width = idealWidth.rounded()

        if let controller = delegate as? FileTableController {
            controller.columnDidAutoFit(table: self)
        }
    }
}

final class FileTableHeaderView: NSTableHeaderView {
    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            let point = convert(event.locationInWindow, from: nil)
            let colIndex = column(at: point)
            if colIndex >= 0, let fileTable = tableView as? FileTableView {
                let rect = headerRect(ofColumn: colIndex)
                let targetCol: Int
                if point.x - rect.minX < 6 && colIndex > 0 {
                    targetCol = colIndex - 1
                } else {
                    targetCol = colIndex
                }
                fileTable.autoFitColumn(at: targetCol)
                return
            }
        }
        super.mouseDown(with: event)
    }
}
