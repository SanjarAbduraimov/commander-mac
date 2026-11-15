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
    private let shareButton = NSButton(title: "Telegram", target: nil, action: nil)
    private let visualEffect = NSVisualEffectView()

    init(model: WindowModel) {
        self.model = model
        buttons = Self.actions.map { NSButton(title: $0.title, target: nil, action: nil) }
        super.init(frame: .zero)

        visualEffect.material = .headerView
        visualEffect.blendingMode = .withinWindow
        visualEffect.state = .active
        visualEffect.translatesAutoresizingMaskIntoConstraints = false
        addSubview(visualEffect)

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

        shareButton.target = self
        shareButton.action = #selector(sharePressed)
        shareButton.bezelStyle = .rounded
        if let paperplane = NSImage(systemSymbolName: "paperplane.fill", accessibilityDescription: "Share") {
            shareButton.image = paperplane.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 11, weight: .medium))
            shareButton.imagePosition = .imageLeading
        }
        shareButton.setAccessibilityIdentifier("selection.share")
        stack.addArrangedSubview(shareButton)

        stack.orientation = .horizontal
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        stack.translatesAutoresizingMaskIntoConstraints = false
        visualEffect.addSubview(stack)
        NSLayoutConstraint.activate([
            visualEffect.topAnchor.constraint(equalTo: topAnchor),
            visualEffect.leadingAnchor.constraint(equalTo: leadingAnchor),
            visualEffect.trailingAnchor.constraint(equalTo: trailingAnchor),
            visualEffect.bottomAnchor.constraint(equalTo: bottomAnchor),

            stack.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: visualEffect.centerYAnchor),
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

    @objc private func sharePressed() {
        let side = model.state.activeSide
        let urls = model.tab(side).targets.map(\.url)
        TelegramSharing.share(urls: urls, from: shareButton)
    }
}
