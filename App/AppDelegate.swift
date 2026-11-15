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
    /// Files handed over by the Dock or `open -a` before the window model exists (a cold launch).
    private var pendingReveals: [URL] = []

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        let options = LaunchOptions(arguments: ProcessInfo.processInfo.arguments)
        let bootstrap = AppBootstrap.load(options, lister: DirectoryReader())
        let persistence = SettingsPersistence(store: bootstrap.store)
        AppKitEffects.applyTheme(bootstrap.settings.appearance.theme)
        let prompts = AlertPrompts()
        let effects = AppKitEffects(prompts: prompts)
        let operations = OperationCenter(prompts: prompts)
        let model = WindowModel(
            state: bootstrap.state,
            settings: bootstrap.settings,
            session: bootstrap.session,
            environment: .live(mounter: NetFSMounter()),
            effects: effects,
            pasteboard: SystemPasteboard(),
            operations: operations
        )
        model.onSessionChange = { persistence.update($0) }
        model.onSettingsChange = { persistence.update($0) }
        self.model = model
        self.operations = operations
        self.persistence = persistence

        windowController = MainWindowController(model: model, sidebarWidth: bootstrap.session.sidebarWidth)
        effects.windowController = windowController
        prompts.window = windowController.window
        keyRouter = KeyRouter(model: model)
        keyRouter.install(in: windowController.window!)
        mainMenu = MainMenu(model: model, keyRouter: keyRouter)
        NSApp.mainMenu = mainMenu.build()
        effects.onSettingsApplied = { [mainMenu] in mainMenu?.refreshKeyEquivalents() }
        windowController.showWindow(nil)
        windowController.window?.makeKeyAndOrderFront(nil)
        windowController.window?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        model.start()
        observeSystem(model)
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()
        pendingReveals.forEach(model.reveal)
        pendingReveals = []

        for warning in bootstrap.warnings {
            let alert = NSAlert()
            alert.messageText = warning.title
            alert.informativeText = warning.detail ?? ""
            alert.beginSheetModal(for: windowController.window!)
        }
    }

    private func observeSystem(_ model: WindowModel) {
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didMountNotification, NSWorkspace.didUnmountNotification, NSWorkspace.didRenameVolumeNotification] {
            workspace.addObserver(forName: name, object: nil, queue: .main) { _ in
                Task { @MainActor in await model.sidebar.refreshVolumes() }
            }
        }
        // SMB shares send no change events; coming back to the app is when their folders get re-read.
        NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                model.appDidBecomeActive()
                if let window = self?.windowController?.window, !window.isVisible || window.isMiniaturized {
                    window.deminiaturize(nil)
                    window.makeKeyAndOrderFront(nil)
                }
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if let window = windowController?.window {
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
        NSApp.activate(ignoringOtherApps: true)
        return true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let operations, !operations.isIdle else { return .terminateNow }
        let count = operations.operations.count
        let alert = NSAlert()
        alert.messageText = count == 1 ? "1 operation is still running." : "\(count) operations are still running."
        alert.informativeText = "Quitting will cancel them."
        alert.addButton(withTitle: "Quit")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return .terminateCancel }

        operations.cancelAll()
        // Cancelled copies delete their partial files; give them a moment, but never hang the quit.
        Task { @MainActor in
            let deadline = ContinuousClock.now + .seconds(5)
            while !operations.isIdle, ContinuousClock.now < deadline {
                try? await Task.sleep(for: .milliseconds(50))
            }
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    func applicationWillTerminate(_ notification: Notification) {
        guard let model, let persistence else { return }
        persistence.update(model.sessionSnapshot())
        persistence.update(model.settings)
        persistence.flushSynchronously()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    /// Dock drops and `open -a Commander <path>`.
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let first = urls.first(where: \.isFileURL) else { return }
        guard let model else {
            pendingReveals = [first]
            return
        }
        model.reveal(first)
        NSApp.activate()
    }

    /// The "Reveal in Commander" service (Info.plist NSServices) from Finder's Quick Actions / Services menu.
    @objc func revealInCommander(_ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        guard let url = (pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL])?.first else {
            error.pointee = "No file was given to Commander." as NSString
            return
        }
        application(NSApp, open: [url])
    }
}
