import AppKit
import Quartz
import UniformTypeIdentifiers
import CommanderController
import CommanderCore

/// In-pane live preview for Total Commander style Quick View (⌃Q).
/// Updates dynamically as the user navigates items in the active pane.
@MainActor
final class QuickViewPanel: NSView {
    var onClose: (() -> Void)?

    private let headerBar = NSVisualEffectView()
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "Quick View")
    private let detailLabel = NSTextField(labelWithString: "")
    private let badgeLabel = NSTextField(labelWithString: "QUICK VIEW")
    private let closeButton = NSButton()
    private let container = NSView()

    private var previewView: QLPreviewView?
    private var textScrollView: NSScrollView?
    private var textView: NSTextView?
    private var folderCard: NSView?
    private let emptyLabel = NSTextField(labelWithString: "Select a file to preview")

    private static let textExtensions: Set<String> = [
        "txt", "text", "md", "markdown", "json", "swift", "py", "js", "ts", "jsx", "tsx",
        "html", "htm", "css", "scss", "sass", "c", "cpp", "cc", "cxx", "h", "hpp", "m", "mm",
        "rs", "go", "java", "kt", "rb", "sh", "bash", "zsh", "yaml", "yml", "toml", "xml",
        "sql", "log", "diff", "patch", "env", "plist", "csv", "tsv", "conf", "ini", "lua",
        "dockerfile", "makefile", "podfile"
    ]

    override init(frame: NSRect) {
        super.init(frame: frame)
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    private func setupViews() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        // Header bar
        headerBar.material = .headerView
        headerBar.blendingMode = .withinWindow
        headerBar.state = .active
        headerBar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(headerBar)

        let topBorder = NSBox()
        topBorder.boxType = .separator
        topBorder.translatesAutoresizingMaskIntoConstraints = false
        headerBar.addSubview(topBorder)

        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        detailLabel.font = NSFont.systemFont(ofSize: 11)
        detailLabel.textColor = NSColor.secondaryLabelColor
        detailLabel.translatesAutoresizingMaskIntoConstraints = false

        badgeLabel.font = NSFont.systemFont(ofSize: 9, weight: .bold)
        badgeLabel.textColor = NSColor.controlAccentColor
        badgeLabel.wantsLayer = true
        badgeLabel.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.12).cgColor
        badgeLabel.layer?.cornerRadius = 4
        badgeLabel.alignment = .center
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false

        if let xmark = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Close Quick View") {
            closeButton.image = xmark.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 14, weight: .medium))
        } else {
            closeButton.title = "×"
        }
        closeButton.isBordered = false
        closeButton.contentTintColor = NSColor.tertiaryLabelColor
        closeButton.target = self
        closeButton.action = #selector(closeClicked)
        closeButton.toolTip = "Close Quick View (Esc or ⌃Q)"
        closeButton.translatesAutoresizingMaskIntoConstraints = false

        let titlesStack = NSStackView(views: [titleLabel, detailLabel])
        titlesStack.orientation = .vertical
        titlesStack.alignment = .leading
        titlesStack.spacing = 1
        titlesStack.translatesAutoresizingMaskIntoConstraints = false

        let headerStack = NSStackView(views: [iconView, titlesStack, NSView(), badgeLabel, closeButton])
        headerStack.orientation = .horizontal
        headerStack.alignment = .centerY
        headerStack.spacing = 8
        headerStack.edgeInsets = NSEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        headerBar.addSubview(headerStack)

        // Content Container
        container.translatesAutoresizingMaskIntoConstraints = false
        addSubview(container)

        // Empty label
        emptyLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        emptyLabel.textColor = NSColor.tertiaryLabelColor
        emptyLabel.alignment = .center
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            headerBar.topAnchor.constraint(equalTo: topAnchor),
            headerBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            headerBar.trailingAnchor.constraint(equalTo: headerBar.trailingAnchor),
            headerBar.heightAnchor.constraint(equalToConstant: 42),

            topBorder.bottomAnchor.constraint(equalTo: headerBar.bottomAnchor),
            topBorder.leadingAnchor.constraint(equalTo: headerBar.leadingAnchor),
            topBorder.trailingAnchor.constraint(equalTo: headerBar.trailingAnchor),

            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),

            badgeLabel.heightAnchor.constraint(equalToConstant: 18),
            badgeLabel.widthAnchor.constraint(equalToConstant: 80),

            closeButton.widthAnchor.constraint(equalToConstant: 20),
            closeButton.heightAnchor.constraint(equalToConstant: 20),

            headerStack.leadingAnchor.constraint(equalTo: headerBar.leadingAnchor),
            headerStack.trailingAnchor.constraint(equalTo: headerBar.trailingAnchor),
            headerStack.centerYAnchor.constraint(equalTo: headerBar.centerYAnchor),

            container.topAnchor.constraint(equalTo: headerBar.bottomAnchor),
            container.leadingAnchor.constraint(equalTo: leadingAnchor),
            container.trailingAnchor.constraint(equalTo: trailingAnchor),
            container.bottomAnchor.constraint(equalTo: bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])
    }

    @objc private func closeClicked() {
        onClose?()
    }

    func preview(item: FileItem?) {
        guard let item else {
            clearContent()
            titleLabel.stringValue = "Quick View"
            detailLabel.stringValue = ""
            iconView.image = NSImage(systemSymbolName: "eye", accessibilityDescription: nil)
            emptyLabel.isHidden = false
            return
        }

        emptyLabel.isHidden = true
        titleLabel.stringValue = item.name
        iconView.image = NSWorkspace.shared.icon(forFile: item.url.path)

        if item.isNavigable {
            detailLabel.stringValue = "\(item.kindName) • Modified \(formatDate(item.modified))"
            showFolderCard(item: item)
        } else if Self.isText(url: item.url) {
            let sizeStr = item.size.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? "--"
            detailLabel.stringValue = "\(sizeStr) • Text/Code Document"
            showTextPreview(url: item.url)
        } else {
            let sizeStr = item.size.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? "--"
            detailLabel.stringValue = "\(sizeStr) • \(item.kindName)"
            showQuickLookPreview(url: item.url)
        }
    }

    private static func isText(url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        if textExtensions.contains(ext) { return true }
        if let values = try? url.resourceValues(forKeys: [.contentTypeKey]),
           let type = values.contentType {
            return type.conforms(to: .text) || type.conforms(to: .sourceCode) || type.conforms(to: .json)
        }
        return false
    }

    private func showFolderCard(item: FileItem) {
        removeCurrentSubviews(except: emptyLabel)
        let card = NSStackView()
        card.orientation = .vertical
        card.alignment = .centerX
        card.spacing = 10
        card.translatesAutoresizingMaskIntoConstraints = false

        let bigIcon = NSImageView()
        bigIcon.image = NSWorkspace.shared.icon(forFile: item.url.path)
        bigIcon.imageScaling = .scaleProportionallyUpOrDown
        bigIcon.translatesAutoresizingMaskIntoConstraints = false
        bigIcon.widthAnchor.constraint(equalToConstant: 64).isActive = true
        bigIcon.heightAnchor.constraint(equalToConstant: 64).isActive = true

        let name = NSTextField(labelWithString: item.name)
        name.font = NSFont.systemFont(ofSize: 15, weight: .bold)

        let path = NSTextField(labelWithString: item.url.path)
        path.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        path.textColor = NSColor.secondaryLabelColor
        path.lineBreakMode = .byTruncatingMiddle

        let modified = NSTextField(labelWithString: "Modified: \(formatDate(item.modified))")
        modified.font = NSFont.systemFont(ofSize: 12)
        modified.textColor = NSColor.secondaryLabelColor

        card.addArrangedSubview(bigIcon)
        card.addArrangedSubview(name)
        card.addArrangedSubview(path)
        card.addArrangedSubview(modified)

        if let created = item.created {
            let createdLabel = NSTextField(labelWithString: "Created: \(formatDate(created))")
            createdLabel.font = NSFont.systemFont(ofSize: 12)
            createdLabel.textColor = NSColor.secondaryLabelColor
            card.addArrangedSubview(createdLabel)
        }

        container.addSubview(card)
        folderCard = card

        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            card.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            card.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 20),
            card.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -20),
        ])
    }

    private func showTextPreview(url: URL) {
        removeCurrentSubviews(except: emptyLabel)

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textColor = NSColor.labelColor
        textView.backgroundColor = NSColor.controlBackgroundColor
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: bounds.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true

        // Read up to 256KB to keep UI instantaneous
        var text = ""
        if let handle = try? FileHandle(forReadingFrom: url) {
            let data = handle.readData(ofLength: 256 * 1024)
            try? handle.close()
            text = String(decoding: data, as: UTF8.self)
            if let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize, fileSize > 256 * 1024 {
                text += "\n\n--- [TRUNCATED FOR PREVIEW] ---"
            }
        }
        textView.string = text

        scrollView.documentView = textView
        container.addSubview(scrollView)
        textScrollView = scrollView
        self.textView = textView

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
    }

    private func showQuickLookPreview(url: URL) {
        if previewView == nil {
            removeCurrentSubviews(except: emptyLabel)
            let ql = QLPreviewView(frame: .zero, style: .normal)
            ql?.translatesAutoresizingMaskIntoConstraints = false
            if let qlView = ql {
                container.addSubview(qlView)
                previewView = qlView
                NSLayoutConstraint.activate([
                    qlView.topAnchor.constraint(equalTo: container.topAnchor),
                    qlView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                    qlView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                    qlView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                ])
            }
        } else {
            removeCurrentSubviews(except: previewView, emptyLabel)
        }

        previewView?.previewItem = url as NSURL
        previewView?.refreshPreviewItem()
    }

    private func removeCurrentSubviews(except keep: NSView?...) {
        let set = Set(keep.compactMap { $0 })
        for sub in container.subviews where !set.contains(sub) {
            sub.removeFromSuperview()
        }
        if let folder = folderCard, !set.contains(folder) { folderCard = nil }
        if let scroll = textScrollView, !set.contains(scroll) { textScrollView = nil; textView = nil }
        if let ql = previewView, !set.contains(ql) { previewView = nil }
    }

    private func clearContent() {
        removeCurrentSubviews(except: emptyLabel)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
