import AppKit
import CommanderController
import CommanderCore
import SwiftUI

@MainActor
final class CopyToState: ObservableObject {
    @Published var text: String {
        didSet {
            guard text != oldValue else { return }
            selection = nil
            refreshFolders()
        }
    }
    /// Folders in the browser: the ones inside the typed folder, or those matching the typed name.
    @Published private(set) var folders: [String] = []
    @Published var selection: Int?
    /// The text `folders` was listed for; until a new listing arrives, keys must not act on the old list.
    private var foldersText: String?
    private var foldersTask: Task<Void, Never>?
    /// Set by the path field: clicks in the lists hand keyboard focus back to it.
    var focusField: (() -> Void)?

    let request: DestinationRequest
    private let model: WindowModel

    init(request: DestinationRequest, model: WindowModel) {
        self.request = request
        self.model = model
        text = PathText.enter(request.suggested.path)
        refreshFolders()
    }

    /// Waits for a pause in typing and drops results for text that has changed since.
    private func refreshFolders() {
        foldersTask?.cancel()
        let typed = text
        foldersTask = Task { [weak self, model] in
            try? await Task.sleep(for: .milliseconds(80))
            guard !Task.isCancelled else { return }
            let found = await model.folderSuggestions(for: typed, limit: nil)
            guard let self, !Task.isCancelled, self.text == typed else { return }
            self.folders = found
            self.foldersText = typed
        }
    }

    private var foldersAreCurrent: Bool { foldersText == text }

    func select(_ index: Int) {
        selection = index
        focusField?()
    }

    func moveSelection(by step: Int) {
        guard foldersAreCurrent, !folders.isEmpty else { return }
        let next = selection.map { $0 + step } ?? (step > 0 ? 0 : folders.count - 1)
        selection = min(max(next, 0), folders.count - 1)
    }

    /// Returns false when nothing is selected, so Return falls through to Copy / Move.
    func enterSelection() -> Bool {
        guard foldersAreCurrent, let selection, folders.indices.contains(selection) else { return false }
        enter(folders[selection])
        return true
    }

    func enter(_ folder: String) {
        text = PathText.enter(folder)
    }

    func goUp() {
        text = PathText.parent(of: (text as NSString).expandingTildeInPath)
    }

    var verb: String { request.kind == .move ? "Move" : "Copy" }

    var title: String {
        "\(verb) \(request.count) \(request.count == 1 ? "item" : "items") to:"
    }

    /// The typed folder with `~` expanded, or nil when the field is empty.
    var typedURL: URL? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        return URL(fileURLWithPath: (trimmed as NSString).expandingTildeInPath, isDirectory: true)
    }
}

struct CopyToView: View {
    @ObservedObject var state: CopyToState
    let onChoose: () -> Void
    let onNewFolder: () -> Void
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(state.title).font(.headline)
            PathTextField(state: state, onConfirm: onConfirm, onCancel: onCancel)
                .frame(height: 24)
            HStack(alignment: .top, spacing: 10) {
                List {
                    section("Recent", state.request.recent)
                    section("Tabs", state.request.tabs)
                    section("Favorites", state.request.favorites)
                }
                .frame(width: 190)
                browser
            }
            .frame(height: 280)
            Text("↑↓ select · ↵ open folder · ⌫ up · ⌘↵ \(state.verb.lowercased()) here")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Button("Choose…", action: onChoose)
                Button("New Folder", action: onNewFolder)
                Spacer()
                Button("Cancel", role: .cancel, action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button(state.verb, action: onConfirm)
                    .keyboardShortcut(.return, modifiers: .command)
                    .buttonStyle(.borderedProminent)
                    .disabled(state.typedURL == nil)
            }
        }
        .padding(20)
        .frame(width: 680)
    }

    private var browser: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(Array(state.folders.enumerated()), id: \.element) { index, folder in
                    HStack(spacing: 6) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: folder))
                            .resizable()
                            .frame(width: 16, height: 16)
                        Text((folder as NSString).lastPathComponent)
                            .accessibilityIdentifier("browser.\((folder as NSString).lastPathComponent)")
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 2)
                    .padding(.horizontal, 4)
                    .background(RoundedRectangle(cornerRadius: 4).fill(index == state.selection ? Color.accentColor.opacity(0.3) : .clear))
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) { state.enter(folder) }
                    // Simultaneous, so a single click selects at once instead of waiting out the double-click time.
                    .simultaneousGesture(TapGesture().onEnded { state.select(index) })
                    .id(folder)
                }
            }
            .overlay {
                if state.folders.isEmpty {
                    Text("No folders").foregroundStyle(.secondary)
                }
            }
            .onChange(of: state.selection) {
                if let selection = state.selection, state.folders.indices.contains(selection) {
                    proxy.scrollTo(state.folders[selection])
                }
            }
        }
    }

    @ViewBuilder
    private func section(_ title: String, _ urls: [URL]) -> some View {
        if !urls.isEmpty {
            Section(title) {
                ForEach(urls, id: \.self) { url in
                    HStack {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                            .resizable()
                            .frame(width: 16, height: 16)
                        Text(FileManager.default.displayName(atPath: url.path))
                            .lineLimit(1)
                    }
                    .help(url.path)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { state.enter(url.path) }
                }
            }
        }
    }
}

/// SwiftUI's TextField ignores programmatic changes while focused and can't be focused reliably in a sheet,
/// so the path is an AppKit field that follows `text` even mid-edit, takes focus when shown, and drives the
/// folder browser from the keyboard.
private struct PathTextField: NSViewRepresentable {
    @ObservedObject var state: CopyToState
    let onConfirm: () -> Void
    let onCancel: () -> Void

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField(string: state.text)
        field.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        field.lineBreakMode = .byTruncatingHead
        field.cell?.isScrollable = true
        field.delegate = context.coordinator
        field.setAccessibilityIdentifier("copyTo.path")
        let focus = { [weak field] in
            guard let field else { return }
            if field.currentEditor() == nil { field.window?.makeFirstResponder(field) }
            field.currentEditor()?.selectedRange = NSRange(location: (field.stringValue as NSString).length, length: 0)
        }
        state.focusField = focus
        DispatchQueue.main.async(execute: focus)
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.view = self
        let text = state.text
        guard field.stringValue != text else { return }
        field.stringValue = text
        if field.currentEditor() == nil { field.window?.makeFirstResponder(field) }
        if let editor = field.currentEditor() {
            editor.string = text
            editor.selectedRange = NSRange(location: (text as NSString).length, length: 0)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(view: self) }

    @MainActor
    final class Coordinator: NSObject, NSTextFieldDelegate {
        var view: PathTextField

        init(view: PathTextField) {
            self.view = view
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            let state = view.state
            switch commandSelector {
            // Esc arrives as `complete:` in a field editor; ⌘. as `cancelOperation:`.
            case #selector(NSResponder.cancelOperation(_:)), #selector(NSResponder.complete(_:)):
                view.onCancel()
            case #selector(NSResponder.moveUp(_:)):
                state.moveSelection(by: -1)
            case #selector(NSResponder.moveDown(_:)):
                state.moveSelection(by: 1)
            case #selector(NSResponder.insertNewline(_:)):
                if !state.enterSelection() { view.onConfirm() }
            case #selector(NSResponder.moveToBeginningOfDocument(_:)):
                state.goUp()
            case #selector(NSResponder.deleteBackward(_:)):
                // Right after entering a folder ("…/Photos/"), ⌫ steps back out instead of eating the slash.
                guard state.text.hasSuffix("/"), state.text != "/", textView.selectedRange().length == 0,
                      textView.selectedRange().location == (state.text as NSString).length
                else { return false }
                state.goUp()
            default:
                return false
            }
            return true
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            view.state.text = field.stringValue
        }
    }
}

/// Runs the Copy To / Move To sheet and resolves to the chosen folder (created first if the user agreed).
@MainActor
final class CopyToPresenter {
    private let model: WindowModel
    private let state: CopyToState
    private var hosting: NSHostingController<CopyToView>!
    private var continuation: CheckedContinuation<URL?, Never>?
    private var sheet: NSWindow?
    private var isAsking = false

    private init(request: DestinationRequest, model: WindowModel) {
        self.model = model
        state = CopyToState(request: request, model: model)
        hosting = NSHostingController(rootView: CopyToView(
            state: state,
            onChoose: { [unowned self] in choose() },
            onNewFolder: { [unowned self] in newFolder() },
            onConfirm: { [unowned self] in confirm() },
            onCancel: { [unowned self] in finish(nil) }
        ))
    }

    static func run(_ request: DestinationRequest, model: WindowModel, over window: NSWindow) async -> URL? {
        let presenter = CopyToPresenter(request: request, model: model)
        let sheet = NSWindow(contentViewController: presenter.hosting)
        presenter.sheet = sheet
        let url = await withCheckedContinuation { continuation in
            presenter.continuation = continuation
            window.beginSheet(sheet)
        }
        // Keeps the presenter alive until the sheet is done; its callbacks hold it unowned.
        withExtendedLifetime(presenter) {}
        return url
    }

    private var sheetWindow: NSWindow? { sheet }

    private func finish(_ url: URL?) {
        guard let continuation else { return }
        self.continuation = nil
        if let sheet { sheet.sheetParent?.endSheet(sheet) }
        continuation.resume(returning: url)
    }

    private func confirm() {
        guard let url = state.typedURL else { return }
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            if isDirectory.boolValue { finish(url) } else { NSSound.beep() }
            return
        }
        guard !isAsking else { return }
        isAsking = true
        Task {
            await createThenFinish(url)
            isAsking = false
        }
    }

    private func createThenFinish(_ url: URL) async {
        let alert = NSAlert()
        alert.messageText = "Folder “\(url.lastPathComponent)” doesn't exist. Create it and \(state.verb.lowercased()) there?"
        alert.addButton(withTitle: "Create & \(state.verb)")
        alert.addButton(withTitle: "Cancel")
        guard await present(alert) == .alertFirstButtonReturn else { return }
        do {
            try await model.createDirectory(at: url)
            finish(url)
        } catch {
            await showError("Couldn't create the folder", error)
        }
    }

    private func newFolder() {
        var isDirectory: ObjCBool = false
        guard let directory = state.typedURL,
              FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory), isDirectory.boolValue
        else { return NSSound.beep() }
        Task {
            do {
                state.enter(try await model.createFolder(in: directory).path)
            } catch {
                await showError("Couldn't create a folder", error)
            }
        }
    }

    private func choose() {
        guard let sheetWindow else { return }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        panel.directoryURL = state.typedURL
        panel.beginSheetModal(for: sheetWindow) { [state] response in
            guard response == .OK, let url = panel.url else { return }
            MainActor.assumeIsolated { state.enter(url.path) }
        }
    }

    private func showError(_ title: String, _ error: Error) async {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = error.localizedDescription
        _ = await present(alert)
    }

    private func present(_ alert: NSAlert) async -> NSApplication.ModalResponse {
        guard let sheetWindow else { return alert.runModal() }
        return await alert.beginSheetModal(for: sheetWindow)
    }
}

