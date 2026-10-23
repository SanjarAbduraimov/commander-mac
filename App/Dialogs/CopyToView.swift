import AppKit
import CommanderController
import CommanderCore
import SwiftUI

@MainActor
final class CopyToState: ObservableObject {
    @Published var text: String {
        didSet { if text != oldValue { suggestions = model.folderSuggestions(for: text) } }
    }
    @Published private(set) var suggestions: [String] = []

    let request: DestinationRequest
    private let model: WindowModel

    init(request: DestinationRequest, model: WindowModel) {
        self.request = request
        self.model = model
        text = request.suggested.path
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

    /// Hides the list once the field already holds exactly the one suggestion.
    var visibleSuggestions: [String] {
        suggestions == [typedURL?.path ?? ""] ? [] : suggestions
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
            PathTextField(text: $state.text, onCancel: onCancel)
                .frame(height: 24)
            if !state.visibleSuggestions.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(state.visibleSuggestions, id: \.self) { path in
                        Text((path as NSString).lastPathComponent)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .onTapGesture { state.text = path + "/" }
                    }
                }
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .controlBackgroundColor)))
            }
            List {
                section("Recent", state.request.recent)
                section("Tabs", state.request.tabs)
                section("Favorites", state.request.favorites)
            }
            .frame(height: 220)
            HStack {
                Button("Choose…", action: onChoose)
                Button("New Folder", action: onNewFolder)
                Spacer()
                Button("Cancel", role: .cancel, action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button(state.verb, action: onConfirm)
                    .keyboardShortcut(.defaultAction)
                    .disabled(state.typedURL == nil)
            }
        }
        .padding(20)
        .frame(width: 520)
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
                        Text(url.deletingLastPathComponent().path)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.head)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture { state.text = url.path }
                }
            }
        }
    }
}

/// SwiftUI's TextField ignores programmatic changes while focused and can't be focused reliably in a sheet,
/// so the path is an AppKit field that follows `text` even mid-edit and takes focus when shown.
private struct PathTextField: NSViewRepresentable {
    @Binding var text: String
    let onCancel: () -> Void

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField(string: text)
        field.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        field.lineBreakMode = .byTruncatingHead
        field.cell?.isScrollable = true
        field.delegate = context.coordinator
        field.setAccessibilityIdentifier("copyTo.path")
        DispatchQueue.main.async { field.window?.makeFirstResponder(field) }
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.text = $text
        context.coordinator.onCancel = onCancel
        guard field.stringValue != text else { return }
        field.stringValue = text
        if let editor = field.currentEditor() {
            editor.string = text
            editor.selectedRange = NSRange(location: (text as NSString).length, length: 0)
        } else {
            field.window?.makeFirstResponder(field)
            field.currentEditor()?.selectedRange = NSRange(location: (text as NSString).length, length: 0)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text, onCancel: onCancel) }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var text: Binding<String>
        var onCancel: () -> Void

        init(text: Binding<String>, onCancel: @escaping () -> Void) {
            self.text = text
            self.onCancel = onCancel
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            // Esc arrives as `complete:` in a field editor; ⌘. as `cancelOperation:`.
            guard commandSelector == #selector(NSResponder.cancelOperation(_:))
                || commandSelector == #selector(NSResponder.complete(_:))
            else { return false }
            onCancel()
            return true
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            text.wrappedValue = field.stringValue
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
                state.text = try await model.createFolder(in: directory).path
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
            MainActor.assumeIsolated { state.text = url.path }
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

