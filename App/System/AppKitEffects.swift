import AppKit
import CommanderController
import CommanderCore

@MainActor
final class AppKitEffects: WindowEffects {
    weak var windowController: MainWindowController?
    var onSettingsApplied: (() -> Void)?
    let prompts: AlertPrompts

    init(prompts: AlertPrompts) {
        self.prompts = prompts
    }

    func stateDidChange(_ change: StateChange) {
        guard let windowController else { return }
        switch change {
        case let .pane(side):
            windowController.pane(side).render()
            windowController.panes.selectionBar.render()
        case .window, .settings:
            windowController.pane(.left).render()
            windowController.pane(.right).render()
            windowController.panes.selectionBar.render()
            windowController.panes.footer.render()
            if change == .settings {
                Self.applyTheme(windowController.model.settings.appearance.theme)
                onSettingsApplied?()
            }
            // Keyboard focus follows the active pane, unless the user is typing in a text field.
            if let window = windowController.window, !(window.firstResponder is NSText) {
                windowController.pane(windowController.activeSide).focusTable()
            }
        case .operations:
            windowController.panes.footer.render()
        case .sidebar:
            windowController.sidebar.reload()
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

    func showSettings() {
        guard let model = windowController?.model else { return }
        SettingsWindowController.show(model: model)
    }

    static func applyTheme(_ theme: Theme) {
        NSApp.appearance = switch theme {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
    func showConnectToServer() {
        windowController?.showConnectToServer()
    }
    func askDestination(default url: URL, kind: OperationKind, count: Int) async -> URL? {
        await prompts.askDestination(default: url, kind: kind, count: count)
    }

    func showAlert(_ alert: AlertMessage) {
        prompts.showAlert(alert)
    }

    func beep() {
        NSSound.beep()
    }
}
