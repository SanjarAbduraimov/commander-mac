import AppKit
import Quartz
import AVKit
import AVFoundation
import PDFKit
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
    private let badgeView = QuickViewBadge()
    private let closeButton = NSButton()
    private let container = NSView()

    private let zoomStack = NSStackView()
    private let zoomOutButton = NSButton()
    private let zoomLabel = NSTextField(labelWithString: "100%")
    private let zoomInButton = NSButton()
    private let zoomResetButton = NSButton()
    private var imageScrollView: NSScrollView?

    private var currentImageView: NSImageView?
    private var avPlayerView: AVPlayerView?
    private var pdfView: PDFView?
    private var textScrollView: NSScrollView?
    private var textView: NSTextView?
    private var previewView: QLPreviewView?
    private var folderCard: NSView?
    private let emptyLabel = NSTextField(labelWithString: "Select a file to preview")

    private static let imageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "gif", "webp", "svg", "tiff", "tif", "bmp", "heic", "ico", "icns"
    ]
    private static let mediaExtensions: Set<String> = [
        "mp4", "mov", "m4v", "mp3", "wav", "m4a", "aac", "flac", "ogg", "aiff"
    ]
    private static let textExtensions: Set<String> = [
        "txt", "text", "md", "markdown", "json", "swift", "py", "js", "ts", "jsx", "tsx",
        "html", "htm", "css", "scss", "sass", "c", "cpp", "cc", "cxx", "h", "hpp", "m", "mm",
        "rs", "go", "java", "kt", "rb", "sh", "bash", "zsh", "yaml", "yml", "toml", "xml",
        "sql", "log", "diff", "patch", "env", "plist", "csv", "tsv", "conf", "ini", "lua",
        "dockerfile", "makefile", "podfile"
    ]

    override var acceptsFirstResponder: Bool { false }

    override init(frame: NSRect) {
        super.init(frame: frame)
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateThemeColors()
    }

    private func updateThemeColors() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        }
    }

    private func setupViews() {
        wantsLayer = true
        updateThemeColors()

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

        badgeView.translatesAutoresizingMaskIntoConstraints = false

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

        // Zoom controls for image preview
        zoomOutButton.isBordered = false
        zoomOutButton.image = NSImage(systemSymbolName: "minus", accessibilityDescription: "Zoom Out")
        zoomOutButton.contentTintColor = NSColor.secondaryLabelColor
        zoomOutButton.target = self
        zoomOutButton.action = #selector(zoomOutClicked)
        zoomOutButton.toolTip = "Zoom Out (⌘-)"
        zoomOutButton.translatesAutoresizingMaskIntoConstraints = false

        zoomLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium)
        zoomLabel.textColor = NSColor.secondaryLabelColor
        zoomLabel.alignment = .center
        zoomLabel.translatesAutoresizingMaskIntoConstraints = false

        zoomInButton.isBordered = false
        zoomInButton.image = NSImage(systemSymbolName: "plus", accessibilityDescription: "Zoom In")
        zoomInButton.contentTintColor = NSColor.secondaryLabelColor
        zoomInButton.target = self
        zoomInButton.action = #selector(zoomInClicked)
        zoomInButton.toolTip = "Zoom In (⌘+)"
        zoomInButton.translatesAutoresizingMaskIntoConstraints = false

        zoomResetButton.isBordered = false
        zoomResetButton.title = "Fit"
        zoomResetButton.font = NSFont.systemFont(ofSize: 10, weight: .semibold)
        zoomResetButton.contentTintColor = NSColor.secondaryLabelColor
        zoomResetButton.target = self
        zoomResetButton.action = #selector(zoomResetClicked)
        zoomResetButton.toolTip = "Fit / Actual Size (⌘0)"
        zoomResetButton.translatesAutoresizingMaskIntoConstraints = false

        zoomStack.orientation = .horizontal
        zoomStack.alignment = .centerY
        zoomStack.spacing = 2
        zoomStack.addArrangedSubview(zoomOutButton)
        zoomStack.addArrangedSubview(zoomLabel)
        zoomStack.addArrangedSubview(zoomInButton)
        zoomStack.addArrangedSubview(zoomResetButton)
        zoomStack.translatesAutoresizingMaskIntoConstraints = false
        zoomStack.isHidden = true

        let headerStack = NSStackView(views: [iconView, titlesStack, NSView(), zoomStack, badgeView, closeButton])
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
            headerBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            headerBar.heightAnchor.constraint(equalToConstant: 42),

            topBorder.bottomAnchor.constraint(equalTo: headerBar.bottomAnchor),
            topBorder.leadingAnchor.constraint(equalTo: headerBar.leadingAnchor),
            topBorder.trailingAnchor.constraint(equalTo: headerBar.trailingAnchor),

            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),

            badgeView.heightAnchor.constraint(equalToConstant: 18),
            badgeView.widthAnchor.constraint(equalToConstant: 78),

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

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Esc
            onClose?()
            return
        }
        super.keyDown(with: event)
    }

    @objc private func closeClicked() {
        onClose?()
    }

    func preview(item: FileItem?) {
        cleanupMedia()

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

        let ext = item.url.pathExtension.lowercased()
        let sizeStr = item.size.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? "--"

        if item.isNavigable {
            detailLabel.stringValue = "\(item.kindName) • Modified \(formatDate(item.modified))"
            showFolderCard(item: item)
        } else if Self.imageExtensions.contains(ext) {
            showImagePreview(url: item.url, sizeStr: sizeStr, kindName: item.kindName)
        } else if Self.mediaExtensions.contains(ext) {
            showAVPreview(url: item.url, sizeStr: sizeStr, kindName: item.kindName)
        } else if ext == "pdf" {
            showPDFPreview(url: item.url, sizeStr: sizeStr)
        } else if Self.isText(url: item.url) {
            detailLabel.stringValue = "\(sizeStr) • Text/Code Document"
            showTextPreview(url: item.url)
        } else {
            detailLabel.stringValue = "\(sizeStr) • \(item.kindName)"
            showQuickLookPreview(url: item.url)
        }
    }

    var isPlayingMedia: Bool {
        avPlayerView?.player != nil
    }

    @discardableResult
    func togglePlayPause() -> Bool {
        guard let player = avPlayerView?.player else { return false }
        if player.timeControlStatus == .playing {
            player.pause()
        } else {
            player.play()
        }
        return true
    }

    func stop() {
        cleanupMedia()
        removeCurrentSubviews(except: emptyLabel)
    }

    private func cleanupMedia() {
        if let player = avPlayerView?.player {
            player.pause()
            player.replaceCurrentItem(with: nil)
            avPlayerView?.player = nil
        }
        avPlayerView?.removeFromSuperview()
        avPlayerView = nil
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

    var isShowingImage: Bool {
        imageScrollView != nil
    }

    private func showImagePreview(url: URL, sizeStr: String, kindName: String) {
        removeCurrentSubviews(except: emptyLabel)

        guard let image = NSImage(contentsOf: url) else {
            let iv = NSImageView()
            iv.image = NSWorkspace.shared.icon(forFile: url.path)
            iv.imageScaling = .scaleProportionallyUpOrDown
            iv.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(iv)
            currentImageView = iv
            detailLabel.stringValue = "\(sizeStr) • \(kindName)"
            zoomStack.isHidden = true
            NSLayoutConstraint.activate([
                iv.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                iv.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                iv.widthAnchor.constraint(equalToConstant: 96),
                iv.heightAnchor.constraint(equalToConstant: 96)
            ])
            return
        }

        let rep = image.representations.first
        let pixelW = rep != nil && rep!.pixelsWide > 0 ? CGFloat(rep!.pixelsWide) : image.size.width
        let pixelH = rep != nil && rep!.pixelsHigh > 0 ? CGFloat(rep!.pixelsHigh) : image.size.height
        detailLabel.stringValue = "\(Int(pixelW)) × \(Int(pixelH)) • \(sizeStr) • \(kindName)"

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.allowsMagnification = true
        scrollView.minMagnification = 0.05
        scrollView.maxMagnification = 10.0
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let clipView = CenteredClipView()
        clipView.drawsBackground = false
        scrollView.contentView = clipView

        let imageView = ZoomableImageView()
        imageView.image = image
        imageView.imageScaling = .scaleAxesIndependently
        imageView.frame = NSRect(x: 0, y: 0, width: max(pixelW, 10), height: max(pixelH, 10))

        scrollView.documentView = imageView
        container.addSubview(scrollView)
        imageScrollView = scrollView
        currentImageView = imageView

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        clipView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(magnificationChanged),
            name: NSView.boundsDidChangeNotification,
            object: clipView
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(magnificationChanged),
            name: NSScrollView.didEndLiveMagnifyNotification,
            object: scrollView
        )

        zoomStack.isHidden = false

        DispatchQueue.main.async { [weak self] in
            self?.fitImageInView()
        }

        imageView.onDoubleClick = { [weak self] in
            self?.toggleFitOrActual()
        }
    }

    private func fitScale() -> CGFloat {
        guard let sv = imageScrollView, let doc = sv.documentView else { return 1.0 }
        let viewport = sv.contentView.bounds.size
        let docSize = doc.frame.size
        guard docSize.width > 0, docSize.height > 0, viewport.width > 0, viewport.height > 0 else { return 1.0 }
        let availW = max(viewport.width - 20, 20)
        let availH = max(viewport.height - 20, 20)
        let scaleX = availW / docSize.width
        let scaleY = availH / docSize.height
        return min(scaleX, scaleY, 1.0)
    }

    func fitImageInView() {
        guard let sv = imageScrollView else { return }
        let scale = fitScale()
        sv.magnification = max(scale, sv.minMagnification)
        updateZoomLabel()
    }

    func toggleFitOrActual() {
        guard let sv = imageScrollView else { return }
        let current = sv.magnification
        let fit = fitScale()
        if abs(current - 1.0) < 0.08 {
            sv.setMagnification(fit, centeredAt: NSPoint(x: sv.contentView.bounds.midX, y: sv.contentView.bounds.midY))
        } else {
            sv.setMagnification(1.0, centeredAt: NSPoint(x: sv.contentView.bounds.midX, y: sv.contentView.bounds.midY))
        }
        updateZoomLabel()
    }

    @objc func zoomInClicked() {
        guard let sv = imageScrollView else { return }
        let newMag = min(sv.magnification * 1.25, sv.maxMagnification)
        sv.setMagnification(newMag, centeredAt: NSPoint(x: sv.contentView.bounds.midX, y: sv.contentView.bounds.midY))
        updateZoomLabel()
    }

    @objc func zoomOutClicked() {
        guard let sv = imageScrollView else { return }
        let newMag = max(sv.magnification / 1.25, sv.minMagnification)
        sv.setMagnification(newMag, centeredAt: NSPoint(x: sv.contentView.bounds.midX, y: sv.contentView.bounds.midY))
        updateZoomLabel()
    }

    @objc func zoomResetClicked() {
        toggleFitOrActual()
    }

    @objc private func magnificationChanged() {
        updateZoomLabel()
    }

    private func updateZoomLabel() {
        guard let sv = imageScrollView else { return }
        let pct = Int(round(sv.magnification * 100))
        zoomLabel.stringValue = "\(pct)%"
    }

    private func showAVPreview(url: URL, sizeStr: String, kindName: String) {
        removeCurrentSubviews(except: emptyLabel)

        let playerView = AVPlayerView()
        playerView.translatesAutoresizingMaskIntoConstraints = false
        playerView.controlsStyle = .inline

        let player = AVPlayer(url: url)
        playerView.player = player
        player.play()

        container.addSubview(playerView)
        avPlayerView = playerView

        detailLabel.stringValue = "\(sizeStr) • \(kindName)"

        NSLayoutConstraint.activate([
            playerView.topAnchor.constraint(equalTo: container.topAnchor),
            playerView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            playerView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
    }

    private func showPDFPreview(url: URL, sizeStr: String) {
        removeCurrentSubviews(except: emptyLabel)

        let pdf = PDFView()
        pdf.translatesAutoresizingMaskIntoConstraints = false
        pdf.autoScales = true

        if let doc = PDFDocument(url: url) {
            pdf.document = doc
            detailLabel.stringValue = "\(doc.pageCount) page\(doc.pageCount == 1 ? "" : "s") • \(sizeStr) • PDF"
        } else {
            detailLabel.stringValue = "\(sizeStr) • PDF Document"
        }

        container.addSubview(pdf)
        pdfView = pdf

        NSLayoutConstraint.activate([
            pdf.topAnchor.constraint(equalTo: container.topAnchor),
            pdf.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            pdf.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            pdf.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
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
        textView.isSelectable = false
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
            qlView.previewItem = url as NSURL
            qlView.refreshPreviewItem()
        }
    }

    private func removeCurrentSubviews(except keep: NSView?...) {
        let set = Set(keep.compactMap { $0 })
        for sub in container.subviews where !set.contains(sub) {
            sub.removeFromSuperview()
        }
        if let iv = currentImageView, !set.contains(iv) { currentImageView = nil }
        if let av = avPlayerView, !set.contains(av) { avPlayerView = nil }
        if let pv = pdfView, !set.contains(pv) { pdfView = nil }
        if let folder = folderCard, !set.contains(folder) { folderCard = nil }
        if let scroll = textScrollView, !set.contains(scroll) { textScrollView = nil; textView = nil }
        if let ql = previewView, !set.contains(ql) { previewView = nil }
        if let isv = imageScrollView, !set.contains(isv) {
            NotificationCenter.default.removeObserver(self, name: NSView.boundsDidChangeNotification, object: isv.contentView)
            NotificationCenter.default.removeObserver(self, name: NSScrollView.didEndLiveMagnifyNotification, object: isv)
            imageScrollView = nil
            zoomStack.isHidden = true
        }
    }

    private func clearContent() {
        cleanupMedia()
        removeCurrentSubviews(except: emptyLabel)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

final class QuickViewBadge: NSView {
    private let label = NSTextField(labelWithString: "QUICK VIEW")

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 4
        layer?.masksToBounds = true
        layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.12).cgColor

        label.font = NSFont.systemFont(ofSize: 9, weight: .bold)
        label.textColor = NSColor.controlAccentColor
        label.alignment = .center
        label.isBezeled = false
        label.drawsBackground = false
        label.isEditable = false
        label.isSelectable = false
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.12).cgColor
        }
    }
}

final class CenteredClipView: NSClipView {
    override func constrainBoundsRect(_ proposedBounds: NSRect) -> NSRect {
        var rect = super.constrainBoundsRect(proposedBounds)
        guard let documentView = documentView else { return rect }
        let docFrame = documentView.frame
        if docFrame.width < bounds.width {
            rect.origin.x = (docFrame.width - bounds.width) / 2.0
        }
        if docFrame.height < bounds.height {
            rect.origin.y = (docFrame.height - bounds.height) / 2.0
        }
        return rect
    }
}

final class ZoomableImageView: NSImageView {
    var onDoubleClick: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            onDoubleClick?()
            return
        }
        super.mouseDown(with: event)
    }
}
