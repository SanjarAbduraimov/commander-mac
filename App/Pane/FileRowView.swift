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
    }
}
