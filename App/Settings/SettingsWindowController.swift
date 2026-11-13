import AppKit
import CommanderController
import SwiftUI

@MainActor
final class SettingsWindowController {
    private static var activeSheet: NSWindow?

    static func show(model: WindowModel, over hostWindow: NSWindow? = nil) {
        let window = hostWindow ?? NSApp.keyWindow
        if let current = activeSheet {
            if let window, window.attachedSheet == current {
                window.endSheet(current)
                activeSheet = nil
                return
            }
        }
        guard let window else { return }

        // Columns change from the table header, not from this window; keep the window's stale copy from undoing them.
        let viewModel = SettingsViewModel(settings: model.settings) { [model] changed in
            var settings = changed
            settings.appearance.columns = model.settings.appearance.columns
            model.updateSettings(settings)
        }
        // Single-pane mode lives in the session, not in AppSettings, so it talks to the window model directly.
        let singlePane = Binding(
            get: { model.isSinglePane },
            set: { if $0 != model.isSinglePane { model.perform(.toggleSinglePane) } }
        )

        let dismiss: () -> Void = {
            if let sheet = activeSheet {
                window.endSheet(sheet)
                activeSheet = nil
            }
        }

        let rootView = SettingsSheetView(model: viewModel, singlePane: singlePane, onDismiss: dismiss)
        let hostingController = NSHostingController(rootView: rootView)
        let sheet = NSWindow(contentViewController: hostingController)
        sheet.styleMask = [.titled]
        activeSheet = sheet
        window.beginSheet(sheet)
    }
}

struct SettingsSheetView: View {
    @Bindable var model: SettingsViewModel
    let singlePane: Binding<Bool>
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Settings")
                    .font(.headline)
                Spacer()
                Button("Done", action: onDismiss)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            TabView {
                AppearanceView(model: model, singlePane: singlePane)
                    .tabItem { Label("Appearance", systemImage: "paintbrush") }
                BehaviorView(model: model)
                    .tabItem { Label("Behavior", systemImage: "gearshape") }
                ClipboardSettingsView(model: model)
                    .tabItem { Label("Clipboard & Paste", systemImage: "doc.on.clipboard") }
                FileAssociationsView(model: model)
                    .tabItem { Label("Associations", systemImage: "app.badge.checkmark") }
                ShortcutsView(model: model)
                    .tabItem { Label("Shortcuts", systemImage: "keyboard") }
            }
            .padding(16)
            .frame(width: 620, height: 490)
        }
        .onExitCommand(perform: onDismiss)
    }
}
