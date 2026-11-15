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
        case .appearance: return "paintpalette.fill"
        case .behavior: return "slider.horizontal.3"
        case .clipboard: return "doc.on.clipboard.fill"
        case .associations: return "app.badge.fill"
        case .shortcuts: return "keyboard.fill"
        }
    }

    var subtitle: String {
        switch self {
        case .appearance: return "Theme, file list fonts, icon scaling, and row dimensions."
        case .behavior: return "Keyboard navigation, confirmation prompts, and startup defaults."
        case .clipboard: return "Clipboard image paste format, naming template, and confirmation."
        case .associations: return "Default application associations for specific file extensions."
        case .shortcuts: return "Customizable keyboard shortcuts for commands and tools."
        }
    }
}

/// Modern floating settings modal card inspired by Claude Desktop / Total Commander.
/// Fully surrounded by a backdrop overlay that dismisses on click or Esc.
struct SettingsModalOverlay: View {
    @Bindable var model: SettingsViewModel
    let singlePane: Binding<Bool>
    let onDismiss: () -> Void

    @State private var selectedTab: SettingsTab = .appearance

    var body: some View {
        ZStack {
            // 1. Semi-transparent backdrop covering 100% of window - clicking outside dismisses!
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    onDismiss()
                }

            // 2. Centered Floating Modal Card (Fixed 780 x 540)
            VStack(spacing: 0) {
                // Header Bar (inside card)
                HStack {
                    Text("Settings")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)

                    Spacer()

                    // Clear, visible Close '✕' Button
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.primary.opacity(0.85))
                            .frame(width: 26, height: 26)
                            .background(Color(NSColor.quaternaryLabelColor).opacity(0.35))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Close (Esc)")
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(Color(NSColor.windowBackgroundColor))

                Divider()

                // Two-Column Body: Left Sidebar + Right Content
                HStack(spacing: 0) {
                    // Left Sidebar (Navigation)
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(SettingsTab.allCases) { tab in
                            Button {
                                selectedTab = tab
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: tab.icon)
                                        .font(.system(size: 13, weight: .medium))
                                        .frame(width: 18)
                                        .foregroundStyle(selectedTab == tab ? Color.white : Color.secondary)

                                    Text(tab.rawValue)
                                        .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .regular))
                                        .foregroundStyle(selectedTab == tab ? Color.white : Color.primary)

                                    Spacer()
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(selectedTab == tab ? Color.accentColor : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 7))
                            }
                            .buttonStyle(.plain)
                        }

                        Spacer()

                        Text("Press Esc to close")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                            .padding(.leading, 8)
                            .padding(.bottom, 6)
                    }
                    .padding(12)
                    .frame(width: 190)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.45))

                    Divider()

                    // Right Detail Pane
                    ScrollView(.vertical) {
                        VStack(alignment: .leading, spacing: 16) {
                            // Section Header
                            VStack(alignment: .leading, spacing: 3) {
                                Text(selectedTab.rawValue)
                                    .font(.system(size: 19, weight: .bold))
                                    .foregroundStyle(.primary)
                                Text(selectedTab.subtitle)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.bottom, 2)

                            // Section Content
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
                        }
                        .padding(20)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(NSColor.windowBackgroundColor))
                }
            }
            .frame(width: 780, height: 540)
            .background(Color(NSColor.windowBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.45), radius: 30, x: 0, y: 14)
            .contentShape(Rectangle())
            .onTapGesture {
                // Do not dismiss when clicking inside the modal card
            }
        }
        .onExitCommand(perform: onDismiss)
    }
}

// MARK: - Reusable Modern Settings Components

struct SettingsCard<Content: View>: View {
    let title: String?
    @ViewBuilder let content: () -> Content

    init(_ title: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .padding(.leading, 2)
            }
            VStack(spacing: 0) {
                content()
            }
            .background(Color(NSColor.controlBackgroundColor).opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(NSColor.separatorColor).opacity(0.35), lineWidth: 0.5)
            )
        }
    }
}

struct SettingsRow<Trailing: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            trailing()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
