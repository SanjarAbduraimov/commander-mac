import AppKit
import CommanderController

/// Modern macOS 15 segmented tab bar with generous padding and elevated active tabs.
final class TabBarView: NSView {
    var onSelect: ((Int) -> Void)?
    var onClose: ((Int) -> Void)?
    var onAdd: (() -> Void)?
    /// Tabs accept dropped files into their folder and spring-load (switch to that tab) while hovered.
    weak var model: WindowModel?
    var dropDestination: ((Int) -> URL?)?
    var onSpringLoad: (@MainActor @Sendable (Int) -> Void)?

    private let stack = NSStackView()
    private var shown: (titles: [String], active: Int)?

    override init(frame: NSRect) {
        super.init(frame: frame)
        stack.orientation = .horizontal
        stack.spacing = 6
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            heightAnchor.constraint(equalToConstant: 38),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    func update(titles: [String], active: Int) {
        if let shown, shown.titles == titles, shown.active == active { return }
        shown = (titles, active)
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        for (index, title) in titles.enumerated() {
            let isActive = index == active
            let tabContainer = NSStackView()
            tabContainer.orientation = .horizontal
            tabContainer.spacing = 6
            tabContainer.alignment = .centerY
            tabContainer.wantsLayer = true
            tabContainer.layer?.cornerRadius = 7
            tabContainer.edgeInsets = NSEdgeInsets(top: 0, left: 10, bottom: 0, right: titles.count > 1 ? 6 : 10)
            tabContainer.translatesAutoresizingMaskIntoConstraints = false
            tabContainer.heightAnchor.constraint(equalToConstant: 28).isActive = true

            if isActive {
                tabContainer.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
                tabContainer.layer?.borderWidth = 1
                tabContainer.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.5).cgColor
                tabContainer.layer?.shadowColor = NSColor.black.cgColor
                tabContainer.layer?.shadowOpacity = 0.07
                tabContainer.layer?.shadowRadius = 2
                tabContainer.layer?.shadowOffset = CGSize(width: 0, height: -1)
            } else {
                tabContainer.layer?.backgroundColor = NSColor.quaternaryLabelColor.withAlphaComponent(0.06).cgColor
                tabContainer.layer?.borderWidth = 1
                tabContainer.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.18).cgColor
                tabContainer.layer?.shadowOpacity = 0
            }

            // Tab button with icon and title
            let tab = DropButton(frame: .zero)
            tab.title = title
            let symbolName = isActive ? "folder.fill" : "folder"
            if let folderImg = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) {
                let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .medium)
                tab.image = folderImg.withSymbolConfiguration(config)
                tab.imagePosition = .imageLeading
            }
            tab.target = self
            tab.action = #selector(selectTab(_:))
            tab.tag = index
            tab.model = model
            tab.destination = { [weak self] in self?.dropDestination?(index) }
            tab.onSpringLoad = { [weak self] in self?.onSpringLoad?(index) }
            tab.isBordered = false
            tab.font = isActive ? NSFont.systemFont(ofSize: 12.5, weight: .semibold) : NSFont.systemFont(ofSize: 12.5, weight: .medium)
            tab.contentTintColor = isActive ? NSColor.labelColor : NSColor.secondaryLabelColor
            tab.lineBreakMode = .byTruncatingMiddle
            tab.translatesAutoresizingMaskIntoConstraints = false
            tab.widthAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
            tab.widthAnchor.constraint(lessThanOrEqualToConstant: 180).isActive = true
            tabContainer.addArrangedSubview(tab)

            // Close button when more than one tab is open
            if titles.count > 1 {
                let close = NSButton(frame: .zero)
                if let closeImg = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close \(title)") {
                    let config = NSImage.SymbolConfiguration(pointSize: 9, weight: .bold)
                    close.image = closeImg.withSymbolConfiguration(config)
                } else {
                    close.title = "×"
                }
                close.target = self
                close.action = #selector(closeTab(_:))
                close.tag = index
                close.isBordered = false
                close.contentTintColor = NSColor.tertiaryLabelColor
                close.translatesAutoresizingMaskIntoConstraints = false
                close.widthAnchor.constraint(equalToConstant: 18).isActive = true
                close.heightAnchor.constraint(equalToConstant: 18).isActive = true
                tabContainer.addArrangedSubview(close)
            }

            stack.addArrangedSubview(tabContainer)
        }

        // Add tab button
        let add = NSButton(frame: .zero)
        if let plusImg = NSImage(systemSymbolName: "plus", accessibilityDescription: "New Tab") {
            let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
            add.image = plusImg.withSymbolConfiguration(config)
        } else {
            add.title = "+"
        }
        add.target = self
        add.action = #selector(addTab)
        add.isBordered = false
        add.wantsLayer = true
        add.layer?.cornerRadius = 7
        add.layer?.backgroundColor = NSColor.quaternaryLabelColor.withAlphaComponent(0.08).cgColor
        add.layer?.borderWidth = 1
        add.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.2).cgColor
        add.contentTintColor = NSColor.secondaryLabelColor
        add.translatesAutoresizingMaskIntoConstraints = false
        add.widthAnchor.constraint(equalToConstant: 28).isActive = true
        add.heightAnchor.constraint(equalToConstant: 28).isActive = true
        add.toolTip = "New Tab (⌘T)"
        stack.addArrangedSubview(add)
    }

    @objc private func selectTab(_ sender: NSButton) {
        onSelect?(sender.tag)
    }

    @objc private func closeTab(_ sender: NSButton) {
        onClose?(sender.tag)
    }

    @objc private func addTab() {
        onAdd?()
    }
}
