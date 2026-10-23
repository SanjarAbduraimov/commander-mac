import AppKit

final class TabBarView: NSView {
    var onSelect: ((Int) -> Void)?
    var onClose: ((Int) -> Void)?
    var onAdd: (() -> Void)?

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
            let tab = NSButton(title: title, target: self, action: #selector(selectTab(_:)))
            tab.tag = index
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
