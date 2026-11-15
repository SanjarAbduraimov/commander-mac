import AppKit
import CommanderController
import CommanderCore

/// The pane's path as clickable folder segments; each segment is also a drop and spring-loading target.
/// A click on the empty space asks for the editable path field instead.
@MainActor
final class BreadcrumbBar: NSView {
    var onEdit: (() -> Void)?

    private let model: WindowModel
    private let side: PaneSide
    private let stack = NSStackView()
    private var shownPath: URL?

    init(model: WindowModel, side: PaneSide) {
        self.model = model
        self.side = side
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 7
        layer?.backgroundColor = NSColor.quaternaryLabelColor.withAlphaComponent(0.08).cgColor
        stack.orientation = .horizontal
        stack.spacing = 3
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
        // Placed by frame in `layout()`: as constraints, a long path's width would widen the whole pane.
        stack.translatesAutoresizingMaskIntoConstraints = true
        addSubview(stack)
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityIdentifier("path.\(side.rawValue)")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    func show(_ path: URL) {
        setAccessibilityValue(path.path)
        guard path != shownPath else { return }
        shownPath = path
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let crumbs = Breadcrumbs.of(path)
        for (index, crumb) in crumbs.enumerated() {
            if index > 0 {
                let separator = NSTextField(labelWithString: "›")
                separator.textColor = NSColor.tertiaryLabelColor
                separator.font = NSFont.systemFont(ofSize: 12, weight: .bold)
                stack.addArrangedSubview(separator)
            }
            stack.addArrangedSubview(segment(crumb, index: index, isLast: index == crumbs.count - 1))
        }
        needsLayout = true
    }

    private func segment(_ crumb: Breadcrumb, index: Int, isLast: Bool) -> NSView {
        let button = DropButton(frame: .zero)
        if index == 0, let home = NSImage(systemSymbolName: "house.fill", accessibilityDescription: "Home / Root") {
            button.image = home.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 11, weight: .medium))
            button.imagePosition = .imageLeading
            button.title = " /"
        } else {
            button.title = crumb.title
        }
        button.isBordered = false
        button.font = NSFont.systemFont(ofSize: 12, weight: isLast ? .semibold : .medium)
        button.contentTintColor = isLast ? NSColor.labelColor : NSColor.secondaryLabelColor
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.setAccessibilityLabel(crumb.title)
        button.model = model
        button.destination = { crumb.url }
        button.onSpringLoad = { [model, side] in model.openFolder(side, crumb.url) }
        button.target = self
        button.action = #selector(segmentClicked(_:))
        button.identifier = NSUserInterfaceItemIdentifier(crumb.url.path)
        return button
    }

    @objc private func segmentClicked(_ sender: NSButton) {
        guard let path = sender.identifier?.rawValue else { return }
        model.openFolder(side, URL(fileURLWithPath: path, isDirectory: true))
    }

    /// Left-aligned while it fits; a long path keeps its end visible and clips the leading segments.
    override func layout() {
        super.layout()
        let size = stack.fittingSize
        stack.frame = NSRect(x: min(0, bounds.width - size.width), y: ((bounds.height - size.height) / 2).rounded(), width: size.width, height: size.height)
    }

    override func mouseDown(with event: NSEvent) {
        onEdit?()
    }
}
