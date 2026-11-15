import AppKit

/// Modern macOS 15 rounded pill selection and cursor indicator.
/// Follows system accent color dynamically and provides soft tints.
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
        let pillRect = bounds.insetBy(dx: 2, dy: 1)
        let pillPath = NSBezierPath(roundedRect: pillRect, xRadius: 5, yRadius: 5)

        if isCursor {
            if isMarked {
                NSColor.controlAccentColor.withAlphaComponent(0.24).setFill()
                pillPath.fill()
                NSColor.controlAccentColor.withAlphaComponent(0.40).setStroke()
                pillPath.lineWidth = 1
                pillPath.stroke()
            } else {
                NSColor.controlAccentColor.withAlphaComponent(0.18).setFill()
                pillPath.fill()
            }
            // Vertical accent pill indicator on the left
            let indicatorRect = NSRect(x: 2, y: 3, width: 2.5, height: bounds.height - 6)
            let indicatorPath = NSBezierPath(roundedRect: indicatorRect, xRadius: 1.25, yRadius: 1.25)
            NSColor.controlAccentColor.setFill()
            indicatorPath.fill()
        } else if isMarked {
            NSColor.systemBlue.withAlphaComponent(0.12).setFill()
            pillPath.fill()
        }

        if isDropTarget {
            NSColor.controlAccentColor.withAlphaComponent(0.14).setFill()
            pillPath.fill()
            NSColor.controlAccentColor.setStroke()
            let ring = NSBezierPath(roundedRect: bounds.insetBy(dx: 3, dy: 1), xRadius: 6, yRadius: 6)
            ring.lineWidth = 2
            ring.stroke()
        }
    }
}
