import AppKit
import CommanderController
import SwiftUI

@MainActor
final class SettingsWindowController {
    private static var activeOverlay: NSView?

    static var isOpen: Bool {
        activeOverlay != nil
    }

    static func dismissActive() {
        guard let current = activeOverlay else { return }
        let window = current.window
        current.removeFromSuperview()
        activeOverlay = nil
        if let window {
            window.makeFirstResponder(nil)
        }
    }

    static func show(model: WindowModel, over hostWindow: NSWindow? = nil) {
        if isOpen {
            dismissActive()
            return
        }
        guard let window = hostWindow ?? NSApp.keyWindow, let contentView = window.contentView else { return }

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
            dismissActive()
        }

        let rootView = SettingsModalOverlay(model: viewModel, singlePane: singlePane, onDismiss: dismiss)
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(hostingView, positioned: .above, relativeTo: nil)

        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: contentView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        ])

        activeOverlay = hostingView
        window.makeFirstResponder(hostingView)
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

struct SettingsModalOverlay: View {
    @Bindable var model: SettingsViewModel
    let singlePane: Binding<Bool>
    let onDismiss: () -> Void

    @State private var selectedTab: SettingsTab = .appearance

    var body: some View {
        ZStack {
            // Semi-transparent backdrop - clicking outside closes the modal!
            Color.black.opacity(0.42)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            // Centered Modal Dialog Card
            VStack(spacing: 0) {
                // Header
                HStack(spacing: 12) {
                    Image(systemName: "gearshape.circle.fill")
                        .font(.system(size: 24))
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

                    // Circular 'X' close button (requested instead of Done)
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 26, height: 26)
                            .background(Color(NSColor.quaternaryLabelColor).opacity(0.18))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Close Settings (Esc)")
                    .keyboardShortcut(.cancelAction)
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
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color(NSColor.separatorColor).opacity(0.5), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.38), radius: 24, x: 0, y: 12)
            .contentShape(Rectangle())
            .onTapGesture {
                // Absorbs taps inside the dialog card so backdrop onTapGesture doesn't fire
            }
        }
        .onExitCommand(perform: onDismiss)
    }
}
