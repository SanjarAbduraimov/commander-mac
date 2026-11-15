import CommanderCore
import CommanderFileSystem
import Foundation

public enum DropOperation: Equatable, Sendable {
    case copy, move, none
}

public enum DropPolicy {
    /// Finder's rule: move within a volume, copy across volumes, ⌥ forces a copy.
    public static func operation(sources: [URL], destination: URL, forceCopy: Bool, sameVolume: (URL, URL) -> Bool) -> DropOperation {
        guard !sources.isEmpty else { return .none }
        let target = destination.standardizedFileURL.pathComponents
        if sources.contains(where: { target.starts(with: $0.standardizedFileURL.pathComponents) }) { return .none }
        if sources.allSatisfy({ $0.deletingLastPathComponent().standardizedFileURL.pathComponents == target }) { return .none }
        if forceCopy { return .copy }
        return sources.allSatisfy { sameVolume($0, destination) } ? .move : .copy
    }
}

public enum RenameSelection {
    /// The UTF-16 length to preselect when rename starts: the stem of a file, the whole name of a folder.
    public static func editableLength(of name: String, kind: FileItem.Kind) -> Int {
        switch kind {
        case .directory, .symlink(toDirectory: true):
            return name.utf16.count
        default:
            guard let dot = name.lastIndex(of: "."), dot != name.startIndex else { return name.utf16.count }
            return name[..<dot].utf16.count
        }
    }
}

public enum RenameText {
    public static func message(_ error: RenameError, newName: String) -> String {
        switch error {
        case .empty: "The name can't be empty."
        case .invalidCharacter: "Names can't contain “/” or “:”."
        case .alreadyExists: "The name “\(newName)” is already taken. Please choose a different name."
        case let .failed(message): message
        }
    }
}

extension WindowModel {
    public func commitRename(_ side: PaneSide, from oldName: String, to newName: String) async -> RenameError? {
        guard newName != oldName, let item = tab(side).items.first(where: { $0.name == oldName }) else { return nil }
        let url = item.url
        do {
            let renamed = try await environment.listingExecutor.run { () throws -> URL in try FileActions.rename(url, to: newName) }
            pendingCursor[side] = renamed.lastPathComponent
            undoStack.push(action: .rename(from: url, to: renamed), description: "Rename '\(oldName)' to '\(newName)'")
            await reloadAndWait(side)
            return nil
        } catch let error as RenameError {
            return error
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    public func dropOperation(_ urls: [URL], on side: PaneSide, intoFolder name: String?, forceCopy: Bool) -> DropOperation {
        dropOperation(urls, to: dropDestination(side, name), forceCopy: forceCopy)
    }

    @discardableResult
    public func drop(_ urls: [URL], on side: PaneSide, intoFolder name: String?, forceCopy: Bool) -> Bool {
        drop(urls, to: dropDestination(side, name), forceCopy: forceCopy)
    }

    func performFileCommand(_ command: Command, on side: PaneSide, scope: CommandScope) {
        let tab = tab(side)
        let urls = tab.targets.map(\.url)
        switch command {
        case .copyToOtherPane: transfer(.copy, from: side)
        case .moveToOtherPane: transfer(.move, from: side)
        case .duplicate:
            guard !urls.isEmpty else { return }
            operations.start(.copy(sources: urls, destination: tab.path))
        case .moveToTrash:
            guard !urls.isEmpty else { return }
            operations.start(.trash(urls))
            mutateTab(side) { $0.clearMarks() }
        case .deleteImmediately:
            guard !urls.isEmpty else { return }
            track {
                guard await self.effects.confirmDeleteImmediately(urls) else { return }
                self.operations.start(.delete(urls))
                self.mutateTab(side) { $0.clearMarks() }
            }
        case .newFolder: createFolder(on: side)
        case .newFile: createFile(on: side)
        case .pasteImage: effects.pasteImage(side)
        case .openWithApp:
            guard !urls.isEmpty else { return }
            effects.openWithAppPrompt(urls)
        case .quickLook:
            guard !urls.isEmpty else { return }
            effects.quickLook(urls)
        case .rename:
            if tab.marked.count > 1 {
                startMultiRename(side)
            } else if let name = tab.cursorItem?.name {
                effects.beginRename(side, name: name)
            }
        case .copyToClipboard, .cutToClipboard:
            guard !urls.isEmpty else { return }
            let isCut = command == .cutToClipboard
            pasteboard.writeFiles(urls, cut: isCut)
            setCut(isCut ? urls : [])
            setCopied(isCut ? [] : urls)
            let count = urls.count
            let noun = count == 1 ? "1 item" : "\(count) items"
            let msg = isCut ? "Cut \(noun) to clipboard" : "Copied \(noun) to clipboard"
            effects.showToast(side, icon: isCut ? "scissors" : "doc.on.doc.fill", message: msg)
        case .paste:
            if let (sources, isCut) = pasteboard.readFiles() {
                if isCut {
                    operations.start(.move(sources: sources, destination: tab.path))
                    pasteboard.clearCut()
                    setCut([])
                    setCopied([])
                } else {
                    operations.start(.copy(sources: sources, destination: tab.path))
                }
            } else if pasteboard.hasImage() {
                effects.pasteImage(side)
            }
        case .copyPath:
            guard !urls.isEmpty else { return }
            pasteboard.writeString(urls.map(\.path).joined(separator: "\n"))
            setCut([])
            setCopied([])
            effects.showToast(side, icon: "doc.on.doc.fill", message: "Path copied to clipboard")
        case .copyName:
            guard !urls.isEmpty else { return }
            pasteboard.writeString(tab.targets.map(\.name).joined(separator: "\n"))
            setCut([])
            setCopied([])
            effects.showToast(side, icon: "doc.on.doc.fill", message: "Name copied to clipboard")
        case .revealInFinder:
            guard !urls.isEmpty else { return }
            effects.revealInFinder(urls)
        case .openInTerminal:
            if scope == .targets, let item = tab.cursorItem, item.isNavigable {
                effects.openInTerminal(item.url)
            } else {
                effects.openInTerminal(tab.path)
            }
        case .showPackageContents:
            if let item = tab.cursorItem, item.kind == .package { navigate(side, to: item.url) }
        default:
            break
        }
    }

    private func dropDestination(_ side: PaneSide, _ name: String?) -> URL {
        if let name, let item = tab(side).items.first(where: { $0.name == name }), item.isNavigable { return item.url }
        return tab(side).path
    }

    private func transfer(_ kind: OperationKind, from side: PaneSide) {
        let sources = tab(side).targets.map(\.url)
        guard !sources.isEmpty else { return }
        if isSinglePane {
            chooseDestination(kind, from: side, suggested: suggestedDestination(from: side))
            return
        }
        let destination = tab(side == .left ? .right : .left).path
        guard settings.behavior.askDestinationForCopyMove else {
            startTransfer(kind, sources: sources, destination: destination, from: side)
            return
        }
        chooseDestination(kind, from: side, suggested: destination)
    }

    func startTransfer(_ kind: OperationKind, sources: [URL], destination: URL, from side: PaneSide) {
        operations.start(kind == .move ? .move(sources: sources, destination: destination) : .copy(sources: sources, destination: destination))
        mutateTab(side) { $0.clearMarks() }
    }

    private func createFolder(on side: PaneSide) {
        let directory = tab(side).path
        let executor = environment.listingExecutor
        track {
            do {
                let folder = try await executor.run { try FileActions.createFolder(in: directory) }
                guard samePath(self.tab(side).path, directory) else { return }
                self.pendingCursor[side] = folder.lastPathComponent
                await self.reloadAndWait(side)
                guard self.tab(side).cursor == folder.lastPathComponent else { return }
                self.effects.beginRename(side, name: folder.lastPathComponent)
            } catch {
                self.effects.showAlert(AlertMessage(title: "Couldn't create a folder", detail: error.localizedDescription))
            }
        }
    }

    public func createFile(on side: PaneSide, named name: String = "Untitled.txt") {
        let directory = tab(side).path
        let executor = environment.listingExecutor
        track {
            do {
                let file = try await executor.run { try FileActions.createFile(named: name, in: directory) }
                guard samePath(self.tab(side).path, directory) else { return }
                self.pendingCursor[side] = file.lastPathComponent
                await self.reloadAndWait(side)
                guard self.tab(side).cursor == file.lastPathComponent else { return }
                self.effects.beginRename(side, name: file.lastPathComponent)
            } catch {
                self.effects.showAlert(AlertMessage(title: "Couldn't create a file", detail: error.localizedDescription))
            }
        }
    }
}
