import AppKit
import CommanderController
import CommanderCore

/// Shown while the active tab has marked items: a summary and the bulk actions.
@MainActor
final class SelectionBarView: NSView {
    private static let actions: [(command: Command, title: String)] = [
        (.copyToOtherPane, "Copy"), (.moveToOtherPane, "Move"), (.moveToTrash, "Trash"),
        (.calculateSize, "Size"), (.unmarkAll, "Clear"),
    ]

    private let model: WindowModel
    private let summary = NSTextField(labelWithString: "")
    private let buttons: [NSButton]

    init(model: WindowModel) {
        self.model = model
        buttons = Self.actions.map { NSButton(title: $0.title, target: nil, action: nil) }
        super.init(frame: .zero)

        summary.font = .systemFont(ofSize: 12, weight: .medium)
        let stack = NSStackView(views: [summary, NSView()])
        for (index, button) in buttons.enumerated() {
            button.tag = index
            button.target = self
            button.action = #selector(buttonPressed(_:))
            button.bezelStyle = .rounded
            button.setAccessibilityIdentifier("selection.\(Self.actions[index].command.rawValue)")
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
        for (button, action) in zip(buttons, Self.actions) {
            let keys = model.bindings.chords(for: action.command).first?.displayString
            button.title = keys.map { "\(action.title)  \($0)" } ?? action.title
            button.isHidden = action.command == .calculateSize && !model.isEnabled(.calculateSize, context: .table)
        }
    }

    @objc private func buttonPressed(_ sender: NSButton) {
        model.perform(Self.actions[sender.tag].command)
    }
}
