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
            let tab = DropButton(frame: .zero)
            tab.title = title
            tab.target = self
            tab.action = #selector(selectTab(_:))
            tab.tag = index
            tab.model = model
            tab.destination = { [weak self] in self?.dropDestination?(index) }
            tab.onSpringLoad = { [weak self] in self?.onSpringLoad?(index) }
            tab.bezelStyle = .recessed
            tab.setButtonType(.pushOnPushOff)
            tab.state = index == active ? .on : .off
            tab.lineBreakMode = .byTruncatingMiddle
            tab.widthAnchor.constraint(lessThanOrEqualToConstant: 160).isActive = true
            stack.addArrangedSubview(tab)

            if titles.count > 1 {
                let close = NSButton(title: "×", target: self, action: #selector(closeTab(_:)))
                close.tag = index
                close.isBordered = false
                close.setAccessibilityLabel("Close \(title)")
                stack.addArrangedSubview(close)
            }
        }
        let add = NSButton(title: "+", target: self, action: #selector(addTab))
        add.isBordered = false
        add.setAccessibilityLabel("New Tab")
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
