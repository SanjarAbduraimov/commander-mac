import AppKit
import CommanderController

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
        stack.spacing = 2
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 6, bottom: 0, right: 6)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            heightAnchor.constraint(equalToConstant: 35),
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
            tabContainer.spacing = 4
            tabContainer.alignment = .centerY
            tabContainer.wantsLayer = true
            tabContainer.layer?.cornerRadius = 6
            tabContainer.edgeInsets = NSEdgeInsets(top: 2, left: 8, bottom: 2, right: 6)

            if isActive {
                tabContainer.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
                tabContainer.layer?.borderWidth = 1
                tabContainer.layer?.borderColor = NSColor.separatorColor.cgColor
            } else {
                tabContainer.layer?.backgroundColor = NSColor.clear.cgColor
                tabContainer.layer?.borderWidth = 0
            }

            let tab = DropButton(frame: .zero)
            tab.title = title
            tab.target = self
            tab.action = #selector(selectTab(_:))
            tab.tag = index
            tab.model = model
            tab.destination = { [weak self] in self?.dropDestination?(index) }
            tab.onSpringLoad = { [weak self] in self?.onSpringLoad?(index) }
            tab.isBordered = false
            tab.font = isActive ? NSFont.systemFont(ofSize: 12, weight: .semibold) : NSFont.systemFont(ofSize: 12)
            tab.contentTintColor = isActive ? NSColor.labelColor : NSColor.secondaryLabelColor
            tab.lineBreakMode = .byTruncatingMiddle
            tab.widthAnchor.constraint(lessThanOrEqualToConstant: 140).isActive = true
            tabContainer.addArrangedSubview(tab)

            if titles.count > 1 {
                let close = NSButton(frame: .zero)
                if let closeImg = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close \(title)") {
                    let config = NSImage.SymbolConfiguration(pointSize: 9, weight: .semibold)
                    close.image = closeImg.withSymbolConfiguration(config)
                } else {
                    close.title = "×"
                }
                close.target = self
                close.action = #selector(closeTab(_:))
                close.tag = index
                close.isBordered = false
                close.contentTintColor = NSColor.tertiaryLabelColor
                close.widthAnchor.constraint(equalToConstant: 14).isActive = true
                close.heightAnchor.constraint(equalToConstant: 14).isActive = true
                tabContainer.addArrangedSubview(close)
            }

            stack.addArrangedSubview(tabContainer)
        }
        let add = NSButton(frame: .zero)
        if let plusImg = NSImage(systemSymbolName: "plus", accessibilityDescription: "New Tab") {
            let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .medium)
            add.image = plusImg.withSymbolConfiguration(config)
        } else {
            add.title = "+"
        }
        add.target = self
        add.action = #selector(addTab)
        add.isBordered = false
        add.contentTintColor = NSColor.secondaryLabelColor
        add.widthAnchor.constraint(equalToConstant: 24).isActive = true
        add.heightAnchor.constraint(equalToConstant: 24).isActive = true
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
