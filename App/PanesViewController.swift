import AppKit
import CommanderController
import CommanderCore

/// The two panes side by side; the selection bar and the footer go below them.
@MainActor
final class PanesViewController: NSViewController, NSSplitViewDelegate {
    let left: PaneViewController
    let right: PaneViewController
    let quickViewPanel = QuickViewPanel()
    let selectionBar: SelectionBarView
    let footer: FooterView
    let model: WindowModel
    private let split = NSSplitView()
    private var shownSinglePane: Bool?
    private var shownQuickViewSide: PaneSide?

    init(model: WindowModel) {
        self.model = model
        left = PaneViewController(model: model, side: .left)
        right = PaneViewController(model: model, side: .right)
        selectionBar = SelectionBarView(model: model)
        footer = FooterView(model: model)
        super.init(nibName: nil, bundle: nil)

        quickViewPanel.onClose = { [weak self] in
            self?.model.closeQuickView()
        }
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
        applyLayout()
        selectionBar.render()
        footer.render()
    }

    /// Single-pane mode hides the right pane; leaving it splits the width in half again.
    /// When Quick View is active (⌃Q), the inactive pane is replaced with QuickViewPanel.
    func applyLayout() {
        let single = model.isSinglePane
        let quickSide = model.quickViewSide

        if single != shownSinglePane || quickSide != shownQuickViewSide {
            shownSinglePane = single
            shownQuickViewSide = quickSide

            // Clear split views
            for subview in split.arrangedSubviews {
                split.removeArrangedSubview(subview)
                subview.removeFromSuperview()
            }

            if single {
                split.addArrangedSubview(left.view)
            } else {
                // Left slot
                if quickSide == .left {
                    split.addArrangedSubview(quickViewPanel)
                } else {
                    split.addArrangedSubview(left.view)
                }

                // Right slot
                if quickSide == .right {
                    split.addArrangedSubview(quickViewPanel)
                } else {
                    split.addArrangedSubview(right.view)
                }
            }

            split.adjustSubviews()
            split.layoutSubtreeIfNeeded()
            if !single {
                split.setPosition((split.bounds.width / 2).rounded(), ofDividerAt: 0)
            }
        }

        updateQuickView()
    }

    func updateQuickView() {
        guard let quickSide = model.quickViewSide else { return }
        let browsingSide: PaneSide = quickSide == .left ? .right : .left
        let currentItem = model.tab(browsingSide).cursorItem
        quickViewPanel.preview(item: currentItem)
    }

    /// Window resizes grow both panes alike instead of only the first one.
    func splitView(_ splitView: NSSplitView, resizeSubviewsWithOldSize oldSize: NSSize) {
        guard splitView.arrangedSubviews.count > 1 else { return splitView.adjustSubviews() }
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
