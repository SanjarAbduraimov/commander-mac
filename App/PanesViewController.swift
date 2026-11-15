import AppKit
import CommanderController
import CommanderCore

/// Modern macOS 15 dual-pane splitter with subtle background, delicate hairline and interactive centered pill grip.
final class ModernSplitView: NSSplitView {
    private var isHovered = false
    private var trackingArea: NSTrackingArea?

    override var dividerThickness: CGFloat { 9 }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        self.trackingArea = area
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        let point = convert(event.locationInWindow, from: nil)
        let hovered = arrangedSubviews.indices.dropLast().contains { index in
            dividerRect(at: index).insetBy(dx: -1, dy: 0).contains(point)
        }
        if hovered != isHovered {
            isHovered = hovered
            needsDisplay = true
        }
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        if isHovered {
            isHovered = false
            needsDisplay = true
        }
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        for index in 0..<max(arrangedSubviews.count - 1, 0) {
            let rect = dividerRect(at: index)
            addCursorRect(rect, cursor: .resizeLeftRight)
        }
    }

    private func dividerRect(at index: Int) -> NSRect {
        guard arrangedSubviews.indices.contains(index), arrangedSubviews.indices.contains(index + 1) else {
            return .zero
        }
        let firstFrame = arrangedSubviews[index].frame
        return NSRect(x: firstFrame.maxX, y: 0, width: dividerThickness, height: bounds.height)
    }

    override func drawDivider(in rect: NSRect) {
        // Modern subtle gutter background
        NSColor.windowBackgroundColor.setFill()
        rect.fill()

        // Delicate 1px center hairline separator
        let hairlineRect = NSRect(x: (rect.midX - 0.5).rounded(), y: 0, width: 1, height: rect.height)
        NSColor.separatorColor.withAlphaComponent(0.45).setFill()
        hairlineRect.fill()

        // Centered pill grip handle
        let handleHeight: CGFloat = 36
        let handleWidth: CGFloat = 4
        let handleRect = NSRect(
            x: (rect.midX - handleWidth / 2).rounded(),
            y: ((rect.height - handleHeight) / 2).rounded(),
            width: handleWidth,
            height: handleHeight
        )
        let handlePath = NSBezierPath(roundedRect: handleRect, xRadius: 2, yRadius: 2)

        if isHovered {
            NSColor.controlAccentColor.setFill()
        } else {
            NSColor.tertiaryLabelColor.withAlphaComponent(0.65).setFill()
        }
        handlePath.fill()
    }
}

/// The two panes side by side; the selection bar and the footer go below them.
@MainActor
final class PanesViewController: NSViewController, NSSplitViewDelegate {
    let left: PaneViewController
    let right: PaneViewController
    let quickViewPanel = QuickViewPanel()
    let selectionBar: SelectionBarView
    let footer: FooterView
    let model: WindowModel
    private let split = ModernSplitView()
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

            let browsingSide: PaneSide = quickSide == .left ? .right : (quickSide == .right ? .left : model.state.activeSide)
            let activePane = browsingSide == .left ? left : right
            DispatchQueue.main.async {
                activePane.focusTable()
            }
        }

        updateQuickView()
    }

    func updateQuickView() {
        guard let quickSide = model.quickViewSide else { return }
        let browsingSide: PaneSide = quickSide == .left ? .right : .left
        let currentItem = model.tab(browsingSide).cursorItem
        quickViewPanel.preview(item: currentItem)

        let activePane = browsingSide == .left ? left : right
        activePane.focusTable()
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
