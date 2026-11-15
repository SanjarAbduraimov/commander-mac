import AppKit
import CommanderController

/// Holding a drag over the same target for 0.7 s opens it, like Finder's spring-loaded folders.
@MainActor
final class SpringLoader {
    private static let delay: Duration = .milliseconds(700)

    private var key: AnyHashable?
    private var timer: Task<Void, Never>?

    /// Restarts the delay only when the target changes, so repeated drag updates over one target don't postpone it.
    func hover(_ key: AnyHashable, action: @escaping @MainActor @Sendable () -> Void) {
        guard key != self.key else { return }
        cancel()
        self.key = key
        timer = Task { [weak self] in
            try? await Task.sleep(for: Self.delay)
            guard !Task.isCancelled else { return }
            self?.key = nil
            action()
        }
    }

    func cancel() {
        timer?.cancel()
        timer = nil
        key = nil
    }
}

enum DragFiles {
    static func urls(_ info: NSDraggingInfo) -> [URL] {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        return info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL] ?? []
    }

    /// ⌥ forces a copy, and so does a source that does not allow moving its files.
    static func forceCopy(_ info: NSDraggingInfo) -> Bool {
        NSEvent.modifierFlags.contains(.option) || !info.draggingSourceOperationMask.contains(.move)
    }

    static func dragOperation(_ operation: DropOperation) -> NSDragOperation {
        switch operation {
        case .copy: .copy
        case .move: .move
        case .none: []
        }
    }
}

/// A button that also accepts dropped files: it highlights while targeted and spring-loads after a pause.
@MainActor
class DropButton: NSButton {
    /// The folder a drop lands in; nil refuses drops.
    var destination: (() -> URL?)?
    var onSpringLoad: (@MainActor @Sendable () -> Void)?
    weak var model: WindowModel?
    /// Called when a drag enters or leaves, for views that show extra drop targets only during a drag.
    var onDragHover: ((Bool) -> Void)?
    var restingBackground: NSColor? {
        didSet { applyHighlight() }
    }

    private let springLoader = SpringLoader()
    private var isTargeted = false {
        didSet { if isTargeted != oldValue { applyHighlight() } }
    }

    private func applyHighlight() {
        wantsLayer = true
        layer?.cornerRadius = 4
        layer?.borderWidth = isTargeted ? 2 : 0
        layer?.borderColor = Palette.accent.cgColor
        layer?.backgroundColor = (isTargeted ? Palette.cursorBackground : restingBackground)?.cgColor
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        if let cell = cell as? NSButtonCell {
            cell.wraps = false
            cell.isScrollable = false
            cell.lineBreakMode = .byTruncatingMiddle
        }
        registerForDraggedTypes([.fileURL])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    private func operation(_ info: NSDraggingInfo) -> NSDragOperation {
        guard let model, let destination = destination?() else { return [] }
        return DragFiles.dragOperation(model.dropOperation(DragFiles.urls(info), to: destination, forceCopy: DragFiles.forceCopy(info)))
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        onDragHover?(true)
        return draggingUpdated(sender)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        isTargeted = true
        if let onSpringLoad { springLoader.hover(ObjectIdentifier(self), action: onSpringLoad) }
        return operation(sender)
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        endTargeting()
        onDragHover?(false)
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        endTargeting()
        onDragHover?(false)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        endTargeting()
        onDragHover?(false)
        guard let model, let destination = destination?() else { return false }
        return model.drop(DragFiles.urls(sender), to: destination, forceCopy: DragFiles.forceCopy(sender))
    }

    private func endTargeting() {
        isTargeted = false
        springLoader.cancel()
    }
}
