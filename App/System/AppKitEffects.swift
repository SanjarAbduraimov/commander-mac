import AppKit
import CommanderController
import CommanderCore

@MainActor
final class AppKitEffects: WindowEffects {
    weak var windowController: MainWindowController?

    func stateDidChange(_ change: StateChange) {
        guard let windowController else { return }
        switch change {
        case let .pane(side):
            windowController.pane(side).render()
        case .window, .settings:
            windowController.pane(.left).render()
            windowController.pane(.right).render()
        case .sidebar, .operations:
            break
        }
    }

    func focusPathField(_ side: PaneSide) {}
    func beginRename(_ side: PaneSide, name: String) {}

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
