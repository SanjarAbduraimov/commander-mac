import AppKit
import CommanderController
import CommanderCore
import CommanderFileSystem

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var model: WindowModel!
    private(set) var operations: OperationCenter!
    private(set) var persistence: SettingsPersistence!
    private var windowController: MainWindowController!
    private var keyRouter: KeyRouter!
    private var mainMenu: MainMenu!

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let options = LaunchOptions(arguments: ProcessInfo.processInfo.arguments)
        let bootstrap = AppBootstrap.load(options, lister: DirectoryReader())
        let persistence = SettingsPersistence(store: bootstrap.store)
        let effects = AppKitEffects()
        let operations = OperationCenter(prompts: PlaceholderPrompts())
        let model = WindowModel(
            state: bootstrap.state,
            settings: bootstrap.settings,
            session: bootstrap.session,
            environment: .live(mounter: PlaceholderMounter()),
            effects: effects,
            pasteboard: PlaceholderPasteboard(),
            operations: operations
        )
        model.onSessionChange = { persistence.update($0) }
        model.onSettingsChange = { persistence.update($0) }
        self.model = model
        self.operations = operations
        self.persistence = persistence

        windowController = MainWindowController(model: model, sidebarWidth: bootstrap.session.sidebarWidth)
        effects.windowController = windowController
        keyRouter = KeyRouter(model: model)
        keyRouter.install(in: windowController.window!)
        mainMenu = MainMenu(model: model, keyRouter: keyRouter)
        NSApp.mainMenu = mainMenu.build()
        effects.onSettingsApplied = { [mainMenu] in mainMenu?.refreshKeyEquivalents() }
        windowController.showWindow(nil)
        NSApp.activate()
        model.start()

        for warning in bootstrap.warnings {
            let alert = NSAlert()
            alert.messageText = warning.title
            alert.informativeText = warning.detail ?? ""
            alert.beginSheetModal(for: windowController.window!)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
