import AppKit
import CommanderController
import CommanderCore

/// A modern macOS 15 unified header bar positioned at the top of the main window.
/// Displays the sidebar toggle button, navigation history (back/forward), quick view, and settings.
/// In windowed mode, it reserves leading space for traffic light controls (close, minimize, zoom).
/// In fullscreen mode, it stays visible at the top so file panes never stick to the top screen bezel.
@MainActor
final class TopHeaderBarView: NSView {
    var onToggleSidebar: (() -> Void)?
    var onBack: (() -> Void)?
    var onForward: (() -> Void)?
    var onToggleQuickView: (() -> Void)?
    var onOpenSettings: (() -> Void)?

    var isSidebarCollapsed: Bool = false {
        didSet {
            sidebarButton.toolTip = isSidebarCollapsed ? "Show Sidebar (⌘B)" : "Hide Sidebar (⌘B)"
            sidebarButton.contentTintColor = isSidebarCollapsed ? .tertiaryLabelColor : .secondaryLabelColor
        }
    }

    var canGoBack: Bool = false {
        didSet {
            backButton.isEnabled = canGoBack
            backButton.contentTintColor = canGoBack ? .labelColor : .tertiaryLabelColor
        }
    }

    var canGoForward: Bool = false {
        didSet {
            forwardButton.isEnabled = canGoForward
            forwardButton.contentTintColor = canGoForward ? .labelColor : .tertiaryLabelColor
        }
    }

    var isQuickViewActive: Bool = false {
        didSet {
            let iconName = isQuickViewActive ? "eye.fill" : "eye"
            let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
            quickViewButton.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "Quick View")?.withSymbolConfiguration(config)
            quickViewButton.contentTintColor = isQuickViewActive ? Palette.accent : .secondaryLabelColor
            quickViewButton.layer?.backgroundColor = isQuickViewActive
                ? Palette.accent.withAlphaComponent(0.12).cgColor
                : NSColor.clear.cgColor
        }
    }

    private let visualEffect = NSVisualEffectView()
    private let bottomBorder = CALayer()
    private let sidebarButton = HeaderIconButton()
    private let backButton = HeaderIconButton()
    private let forwardButton = HeaderIconButton()
    private let quickViewButton = HeaderIconButton()
    private let settingsButton = HeaderIconButton()
    private let leadingSpacer = NSView()

    override init(frame: NSRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true

        visualEffect.translatesAutoresizingMaskIntoConstraints = false
        visualEffect.material = .headerView
        visualEffect.blendingMode = .withinWindow
        visualEffect.state = .followsWindowActiveState
        addSubview(visualEffect)

        // Trailing bottom border line
        bottomBorder.backgroundColor = NSColor.separatorColor.withAlphaComponent(0.2).cgColor
        layer?.addSublayer(bottomBorder)

        leadingSpacer.translatesAutoresizingMaskIntoConstraints = false

        // Sidebar Toggle Button
        let sidebarConfig = NSImage.SymbolConfiguration(pointSize: 13.5, weight: .regular)
        sidebarButton.image = NSImage(systemSymbolName: "sidebar.leading", accessibilityDescription: "Toggle Sidebar")?.withSymbolConfiguration(sidebarConfig)
        sidebarButton.toolTip = "Hide Sidebar (⌘B)"
        sidebarButton.contentTintColor = .secondaryLabelColor
        sidebarButton.target = self
        sidebarButton.action = #selector(sidebarClicked)

        // History Back Button
        let navConfig = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        backButton.image = NSImage(systemSymbolName: "chevron.left", accessibilityDescription: "Back")?.withSymbolConfiguration(navConfig)
        backButton.toolTip = "Back (⌘[)"
        backButton.isEnabled = false
        backButton.contentTintColor = .tertiaryLabelColor
        backButton.target = self
        backButton.action = #selector(backClicked)

        // History Forward Button
        forwardButton.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: "Forward")?.withSymbolConfiguration(navConfig)
        forwardButton.toolTip = "Forward (⌘])"
        forwardButton.isEnabled = false
        forwardButton.contentTintColor = .tertiaryLabelColor
        forwardButton.target = self
        forwardButton.action = #selector(forwardClicked)

        // Quick View Button
        let eyeConfig = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        quickViewButton.image = NSImage(systemSymbolName: "eye", accessibilityDescription: "Quick View")?.withSymbolConfiguration(eyeConfig)
        quickViewButton.toolTip = "Quick View (⌃Q)"
        quickViewButton.contentTintColor = .secondaryLabelColor
        quickViewButton.target = self
        quickViewButton.action = #selector(quickViewClicked)

        // Settings Button
        let gearConfig = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        settingsButton.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Settings")?.withSymbolConfiguration(gearConfig)
        settingsButton.toolTip = "Settings (⌘,)"
        settingsButton.contentTintColor = .secondaryLabelColor
        settingsButton.target = self
        settingsButton.action = #selector(settingsClicked)

        let navGroup = NSStackView(views: [backButton, forwardButton])
        navGroup.orientation = .horizontal
        navGroup.spacing = 2
        navGroup.alignment = .centerY
        navGroup.translatesAutoresizingMaskIntoConstraints = false

        let leftCluster = NSStackView(views: [leadingSpacer, sidebarButton, navGroup])
        leftCluster.orientation = .horizontal
        leftCluster.spacing = 6
        leftCluster.alignment = .centerY
        leftCluster.translatesAutoresizingMaskIntoConstraints = false

        let rightCluster = NSStackView(views: [quickViewButton, settingsButton])
        rightCluster.orientation = .horizontal
        rightCluster.spacing = 6
        rightCluster.alignment = .centerY
        rightCluster.translatesAutoresizingMaskIntoConstraints = false

        addSubview(leftCluster)
        addSubview(rightCluster)

        NSLayoutConstraint.activate([
            visualEffect.leadingAnchor.constraint(equalTo: leadingAnchor),
            visualEffect.trailingAnchor.constraint(equalTo: trailingAnchor),
            visualEffect.topAnchor.constraint(equalTo: topAnchor),
            visualEffect.bottomAnchor.constraint(equalTo: bottomAnchor),

            leadingSpacer.widthAnchor.constraint(equalToConstant: 74),
            leadingSpacer.heightAnchor.constraint(equalToConstant: 28),

            leftCluster.leadingAnchor.constraint(equalTo: leadingAnchor),
            leftCluster.centerYAnchor.constraint(equalTo: centerYAnchor),

            rightCluster.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            rightCluster.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func layout() {
        super.layout()
        bottomBorder.frame = NSRect(x: 0, y: 0, width: bounds.width, height: 0.5)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        effectiveAppearance.performAsCurrentDrawingAppearance {
            bottomBorder.backgroundColor = NSColor.separatorColor.withAlphaComponent(0.2).cgColor
        }
    }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            window?.zoom(nil)
        } else {
            window?.performDrag(with: event)
        }
    }

    @objc private func sidebarClicked() {
        onToggleSidebar?()
    }

    @objc private func backClicked() {
        onBack?()
    }

    @objc private func forwardClicked() {
        onForward?()
    }

    @objc private func quickViewClicked() {
        onToggleQuickView?()
    }

    @objc private func settingsClicked() {
        onOpenSettings?()
    }
}

/// A button with subtle rounded pill hover background and crisp symbol styling.
@MainActor
final class HeaderIconButton: NSButton {
    private var trackingArea: NSTrackingArea?
    private var isHovered = false

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        isBordered = false
        bezelStyle = .accessoryBarAction
        imagePosition = .imageOnly
        layer?.cornerRadius = 6
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 28),
            heightAnchor.constraint(equalToConstant: 28)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeInActiveApp], owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        isHovered = true
        updateBackground()
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        isHovered = false
        updateBackground()
    }

    private func updateBackground() {
        guard isEnabled else {
            layer?.backgroundColor = NSColor.clear.cgColor
            return
        }
        if isHovered {
            effectiveAppearance.performAsCurrentDrawingAppearance {
                layer?.backgroundColor = NSColor.quaternaryLabelColor.withAlphaComponent(0.15).cgColor
            }
        } else {
            layer?.backgroundColor = NSColor.clear.cgColor
        }
    }
}
