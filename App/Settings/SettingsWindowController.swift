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
        sheet.styleMask = [.titled, .fullSizeContentView]
        sheet.titleVisibility = .hidden
        sheet.titlebarAppearsTransparent = true
        activeSheet = sheet
        window.beginSheet(sheet)
    }
}

enum SettingsTab: String, CaseIterable, Identifiable {
    case appearance = "Appearance"
    case behavior = "Behavior"
    case clipboard = "Clipboard"
    case associations = "Associations"
    case shortcuts = "Shortcuts"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .appearance: return "paintbrush.fill"
        case .behavior: return "gearshape.fill"
        case .clipboard: return "doc.on.clipboard.fill"
        case .associations: return "app.badge.checkmark.fill"
        case .shortcuts: return "keyboard.fill"
        }
    }
}

struct SettingsSheetView: View {
    @Bindable var model: SettingsViewModel
    let singlePane: Binding<Bool>
    let onDismiss: () -> Void

    @State private var selectedTab: SettingsTab = .appearance

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "gearshape.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(.blue)

                Text("Settings")
                    .font(.title3.bold())

                Spacer()

                // Modern Segmented Pill Selector
                HStack(spacing: 3) {
                    ForEach(SettingsTab.allCases) { tab in
                        Button {
                            selectedTab = tab
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 11, weight: .semibold))
                                Text(tab.rawValue)
                                    .font(.system(size: 12, weight: selectedTab == tab ? .semibold : .regular))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(selectedTab == tab ? Color.accentColor : Color.clear)
                            .foregroundStyle(selectedTab == tab ? Color.white : Color.primary)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color(NSColor.separatorColor), lineWidth: 0.5))

                Spacer()

                Button("Done", action: onDismiss)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Selected Tab Content
            Group {
                switch selectedTab {
                case .appearance:
                    AppearanceView(model: model, singlePane: singlePane)
                case .behavior:
                    BehaviorView(model: model)
                case .clipboard:
                    ClipboardSettingsView(model: model)
                case .associations:
                    FileAssociationsView(model: model)
                case .shortcuts:
                    ShortcutsView(model: model)
                }
            }
            .padding(18)
            .frame(width: 680, height: 490)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
        }
        .onExitCommand(perform: onDismiss)
    }
}
