import AppKit

/// Shown over the column header while files are dragged over the pane: dropping here moves them to the
/// enclosing folder, holding goes up one level.
@MainActor
final class ParentDropStrip: DropButton {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        title = "↑ Enclosing folder"
        isBordered = false
        font = .systemFont(ofSize: 11, weight: .medium)
        contentTintColor = Palette.accent
        restingBackground = .windowBackgroundColor
        setAccessibilityIdentifier("parentDropStrip")
        isHidden = true
        // Pinned to the scroll view's edges; the button's own width must not squeeze the table.
        setContentHuggingPriority(.init(1), for: .horizontal)
        setContentCompressionResistancePriority(.init(1), for: .horizontal)
    }
}
