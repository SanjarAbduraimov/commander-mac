import AppKit
import CommanderController
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    private static var shared: SettingsWindowController?

    static func show(model: WindowModel) {
        if shared == nil {
            let viewModel = SettingsViewModel(settings: model.settings) { [model] in model.updateSettings($0) }
            shared = SettingsWindowController(viewModel: viewModel)
        }
        shared?.showWindow(nil)
        shared?.window?.makeKeyAndOrderFront(nil)
    }

    private init(viewModel: SettingsViewModel) {
        let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(model: viewModel)))
        window.title = "Settings"
        window.styleMask = [.titled, .closable]
        window.center()
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }
}

struct SettingsView: View {
    @Bindable var model: SettingsViewModel

    var body: some View {
        TabView {
            AppearanceView(model: model).tabItem { Label("Appearance", systemImage: "paintbrush") }
            BehaviorView(model: model).tabItem { Label("Behavior", systemImage: "gearshape") }
            ShortcutsView(model: model).tabItem { Label("Shortcuts", systemImage: "keyboard") }
        }
        .padding(20)
        .frame(width: 560, height: 480)
    }
}
