import AppKit

/// Cursor and marked rows look different (prototype): marked rows get a tint, the cursor row a stronger tint
/// and an accent bar on the left edge — and only in the active pane.
final class FileRowView: NSTableRowView {
    var isCursor = false {
        didSet { if isCursor != oldValue { needsDisplay = true } }
    }

    var isMarked = false {
        didSet { if isMarked != oldValue { needsDisplay = true } }
    }

    var isDropTarget = false {
        didSet { if isDropTarget != oldValue { needsDisplay = true } }
    }

    override func drawBackground(in dirtyRect: NSRect) {
        super.drawBackground(in: dirtyRect)
        if isCursor {
            Palette.cursorBackground.setFill()
            bounds.fill()
            Palette.accent.setFill()
            NSRect(x: 0, y: 0, width: 2, height: bounds.height).fill()
        } else if isMarked {
            Palette.markedBackground.setFill()
            bounds.fill()
        }
        if isDropTarget {
            Palette.cursorBackground.setFill()
            bounds.fill()
            Palette.accent.setStroke()
            let ring = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 4, yRadius: 4)
            ring.lineWidth = 2
            ring.stroke()
        }
    }
}
