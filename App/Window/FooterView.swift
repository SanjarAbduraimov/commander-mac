import AppKit
import CommanderController
import CommanderCore

/// Shortcut hints when idle; one progress row per running operation (at most three) while working,
/// plus a row for a running folder-size calculation.
@MainActor
final class FooterView: NSView {
    private static let maxRows = 3

    var onOpenTransferManager: (() -> Void)?
    private let model: WindowModel
    private let stack = NSStackView()
    private var shownOperationIDs: [UUID] = []
    private var rows: [UUID: OperationRow] = [:]
    private var showsHints = false
    private var shownHints: [FooterHint] = []
    private lazy var sizeRow = SizeRow { [model] in model.cancelSizeCalculation() }

    init(model: WindowModel) {
        self.model = model
        super.init(frame: .zero)
        stack.orientation = .vertical
        stack.spacing = 0
        stack.alignment = .width
        stack.edgeInsets = NSEdgeInsets(top: 2, left: 12, bottom: 2, right: 12)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 28),
        ])
        setAccessibilityIdentifier("footer")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    func render() {
        sizeRow.removeFromSuperview()
        renderOperations()
        guard let progress = model.sizeProgress else { return }
        if showsHints {
            showsHints = false
            clear()
        }
        sizeRow.update(progress)
        stack.addArrangedSubview(sizeRow)
    }

    private func renderOperations() {
        let operations = model.operations.operations
        guard !operations.isEmpty else {
            if !showsHints {
                clear()
                shownOperationIDs = []
                rows = [:]
            }
            if model.sizeProgress == nil { renderHints() }
            return
        }

        let visible = Array(operations.prefix(Self.maxRows))
        let ids = visible.map(\.id)
        if showsHints || ids != shownOperationIDs || stack.arrangedSubviews.count != visible.count + (operations.count > Self.maxRows ? 1 : 0) {
            showsHints = false
            clear()
            rows = [:]
            for state in visible {
                let row = OperationRow(
                    onCancel: { [model] in model.operations.cancel(state.id) },
                    onOpenManager: { [weak self] in self?.onOpenTransferManager?() }
                )
                rows[state.id] = row
                stack.addArrangedSubview(row)
            }
            if operations.count > Self.maxRows {
                let more = NSTextField(labelWithString: "+\(operations.count - Self.maxRows) more")
                more.font = .systemFont(ofSize: 11)
                more.textColor = .secondaryLabelColor
                stack.addArrangedSubview(more)
            }
            shownOperationIDs = ids
        }
        for state in visible { rows[state.id]?.update(state) }
    }

    private func renderHints() {
        let hints = FooterHints.items(bindings: model.bindings, behavior: model.settings.behavior)
        guard !showsHints || hints != shownHints else { return }
        showsHints = true
        shownHints = hints
        shownOperationIDs = []
        rows = [:]
        clear()
        let line = NSStackView()
        line.orientation = .horizontal
        line.spacing = 14
        line.addArrangedSubview(NSView())
        for hint in hints {
            let key = NSTextField(labelWithString: hint.keys)
            key.font = .monospacedSystemFont(ofSize: 10, weight: .medium)
            key.wantsLayer = true
            key.layer?.borderWidth = 1
            key.layer?.borderColor = NSColor.separatorColor.cgColor
            key.layer?.cornerRadius = 3
            let title = NSTextField(labelWithString: hint.title)
            title.font = .systemFont(ofSize: 11)
            title.textColor = .secondaryLabelColor
            let pair = NSStackView(views: [key, title])
            pair.spacing = 4
            line.addArrangedSubview(pair)
        }
        line.addArrangedSubview(NSView())
        stack.addArrangedSubview(line)
        if let first = line.arrangedSubviews.first, let last = line.arrangedSubviews.last {
            first.widthAnchor.constraint(equalTo: last.widthAnchor).isActive = true
        }
    }

    private func clear() {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
    }
}

@MainActor
private final class SizeRow: NSStackView {
    private let progress = NSProgressIndicator()
    private let label = NSTextField(labelWithString: "")
    private let onCancel: () -> Void

    init(onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
        super.init(frame: .zero)
        orientation = .horizontal
        spacing = 8
        progress.isIndeterminate = false
        progress.style = .bar
        progress.controlSize = .small
        progress.widthAnchor.constraint(equalToConstant: 160).isActive = true
        label.font = .systemFont(ofSize: 11)
        label.setAccessibilityIdentifier("footer.size")
        let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancelPressed))
        cancel.controlSize = .small
        cancel.bezelStyle = .rounded
        addArrangedSubview(progress)
        addArrangedSubview(label)
        addArrangedSubview(NSView())
        addArrangedSubview(cancel)
        heightAnchor.constraint(equalToConstant: 24).isActive = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    func update(_ state: SizeProgress) {
        progress.maxValue = Double(max(state.total, 1))
        progress.doubleValue = Double(state.done)
        label.stringValue = SizeText.progress(state)
    }

    @objc private func cancelPressed() {
        onCancel()
    }
}

@MainActor
private final class OperationRow: NSStackView {
    private let progress = NSProgressIndicator()
    private let label = NSTextField(labelWithString: "")
    private let onCancel: () -> Void
    private let onOpenManager: (() -> Void)?

    init(onCancel: @escaping () -> Void, onOpenManager: (() -> Void)? = nil) {
        self.onCancel = onCancel
        self.onOpenManager = onOpenManager
        super.init(frame: .zero)
        orientation = .horizontal
        spacing = 8
        progress.isIndeterminate = false
        progress.style = .bar
        progress.controlSize = .small
        progress.widthAnchor.constraint(equalToConstant: 160).isActive = true
        label.font = .systemFont(ofSize: 11)
        label.lineBreakMode = .byTruncatingTail
        let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancelPressed))
        cancel.controlSize = .small
        cancel.bezelStyle = .rounded

        let managerBtn = NSButton(title: "", target: self, action: #selector(openManagerPressed))
        managerBtn.bezelStyle = .inline
        managerBtn.isBordered = false
        if let icon = NSImage(systemSymbolName: "arrow.up.right.square", accessibilityDescription: "Transfer Manager") {
            managerBtn.image = icon.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 12, weight: .regular))
        }
        managerBtn.toolTip = "Background Transfer Manager"

        addArrangedSubview(progress)
        addArrangedSubview(label)
        addArrangedSubview(managerBtn)
        addArrangedSubview(NSView())
        addArrangedSubview(cancel)
        heightAnchor.constraint(equalToConstant: 24).isActive = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    func update(_ state: OperationState) {
        let p = state.progress
        // Bytes when known; operations that move no data (Trash, empty files) advance by item count.
        if p.totalBytes > 0 {
            progress.maxValue = Double(p.totalBytes)
            progress.doubleValue = Double(p.completedBytes)
        } else {
            progress.maxValue = Double(max(p.totalFiles, 1))
            progress.doubleValue = Double(p.completedFiles)
        }
        label.stringValue = OperationText.summary(state)
    }

    @objc private func cancelPressed() {
        onCancel()
    }

    @objc private func openManagerPressed() {
        onOpenManager?()
    }
}
