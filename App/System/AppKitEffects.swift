import AppKit
import CommanderController
import CommanderCore

@MainActor
final class AppKitEffects: WindowEffects {
    weak var windowController: MainWindowController?
    var onSettingsApplied: (() -> Void)?

    func stateDidChange(_ change: StateChange) {
        guard let windowController else { return }
        switch change {
        case let .pane(side):
            windowController.pane(side).render()
        case .window, .settings:
            windowController.pane(.left).render()
            windowController.pane(.right).render()
            if change == .settings { onSettingsApplied?() }
            // Keyboard focus follows the active pane, unless the user is typing in a text field.
            if let window = windowController.window, !(window.firstResponder is NSText) {
                windowController.pane(windowController.activeSide).focusTable()
            }
        case .sidebar, .operations:
            break
        }
    }

    func focusPathField(_ side: PaneSide) {
        windowController?.pane(side).focusPathField()
    }

    func beginRename(_ side: PaneSide, name: String) {
        windowController?.pane(side).beginRename(name)
    }

    func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    func revealInFinder(_ urls: [URL]) {
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    func openInTerminal(_ directory: URL) {
        let terminal = URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
        NSWorkspace.shared.open([directory], withApplicationAt: terminal, configuration: NSWorkspace.OpenConfiguration())
    }

    func showSettings() {}
    func showConnectToServer() {}
    func askDestination(default url: URL, kind: OperationKind, count: Int) async -> URL? { nil }
    func showAlert(_ alert: AlertMessage) {}

    func beep() {
        NSSound.beep()
    }
}
