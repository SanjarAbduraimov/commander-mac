import AppKit
import CommanderController
import CommanderCore

/// The two panes side by side; the selection bar and the footer go below them.
@MainActor
final class PanesViewController: NSViewController, NSSplitViewDelegate {
    let left: PaneViewController
    let right: PaneViewController
    let selectionBar: SelectionBarView
    let footer: FooterView
    private let split = NSSplitView()

    init(model: WindowModel) {
        left = PaneViewController(model: model, side: .left)
        right = PaneViewController(model: model, side: .right)
        selectionBar = SelectionBarView(model: model)
        footer = FooterView(model: model)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func loadView() {
        split.isVertical = true
        split.dividerStyle = .thin
        split.delegate = self
        addChild(left)
        addChild(right)
        split.addArrangedSubview(left.view)
        split.addArrangedSubview(right.view)

        let separator = NSBox()
        separator.boxType = .separator
        let stack = NSStackView(views: [split, selectionBar, separator, footer])
        stack.orientation = .vertical
        stack.spacing = 0
        stack.alignment = .width
        view = stack
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        split.layoutSubtreeIfNeeded()
        split.setPosition(split.bounds.width / 2, ofDividerAt: 0)
        selectionBar.render()
        footer.render()
    }

    /// Window resizes grow both panes alike instead of only the first one.
    func splitView(_ splitView: NSSplitView, resizeSubviewsWithOldSize oldSize: NSSize) {
        let ratio = oldSize.width > 0 ? left.view.frame.width / oldSize.width : 0.5
        splitView.adjustSubviews()
        splitView.setPosition((splitView.bounds.width * ratio).rounded(), ofDividerAt: 0)
    }

    func splitView(_ splitView: NSSplitView, constrainMinCoordinate proposedMinimumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        max(proposedMinimumPosition, 280)
    }

    func splitView(_ splitView: NSSplitView, constrainMaxCoordinate proposedMaximumPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        min(proposedMaximumPosition, splitView.bounds.width - 280)
    }
}
