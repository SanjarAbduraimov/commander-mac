import AppKit
import CommanderController
import CommanderCore

/// Shown while the active tab has marked items: a summary and the three bulk actions.
@MainActor
final class SelectionBarView: NSView {
    private let model: WindowModel
    private let summary = NSTextField(labelWithString: "")
    private let buttons: [(Command, NSButton)]

    init(model: WindowModel) {
        self.model = model
        buttons = [(Command.copyToOtherPane, "Copy"), (.moveToOtherPane, "Move"), (.moveToTrash, "Trash")].map { command, title in
            (command, NSButton(title: title, target: nil, action: nil))
        }
        super.init(frame: .zero)

        summary.font = .systemFont(ofSize: 12, weight: .medium)
        let stack = NSStackView(views: [summary, NSView()])
        for (index, (_, button)) in buttons.enumerated() {
            button.tag = index
            button.target = self
            button.action = #selector(buttonPressed(_:))
            button.bezelStyle = .rounded
            stack.addArrangedSubview(button)
        }
        stack.orientation = .horizontal
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            heightAnchor.constraint(equalToConstant: 42),
        ])
        setAccessibilityIdentifier("selectionBar")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    func render() {
        let side = model.state.activeSide
        guard let text = PaneText.selectionSummary(model.tab(side), side: side) else {
            isHidden = true
            return
        }
        isHidden = false
        summary.stringValue = text
        for (command, button) in buttons {
            let title = button.tag == 0 ? "Copy" : button.tag == 1 ? "Move" : "Trash"
            let keys = model.bindings.chords(for: command).first?.displayString
            button.title = keys.map { "\(title)  \($0)" } ?? title
        }
    }

    @objc private func buttonPressed(_ sender: NSButton) {
        model.perform(buttons[sender.tag].0)
    }
}
