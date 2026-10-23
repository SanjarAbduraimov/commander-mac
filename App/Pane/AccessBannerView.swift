import AppKit
import CommanderController

/// Why a folder shows no items: missing Full Disk Access (with a shortcut to the setting) or another read error.
@MainActor
final class AccessBannerView: NSView {
    private static let privacySettings = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!

    private let title = NSTextField(wrappingLabelWithString: "")
    private let detail = NSTextField(wrappingLabelWithString: "")
    private let button = NSButton(title: "Open Privacy Settings", target: nil, action: nil)

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.systemYellow.withAlphaComponent(0.15).cgColor
        title.font = .systemFont(ofSize: 12, weight: .semibold)
        detail.font = .systemFont(ofSize: 11)
        detail.textColor = .secondaryLabelColor
        button.target = self
        button.action = #selector(openSettings)
        button.controlSize = .small
        button.bezelStyle = .rounded

        let text = NSStackView(views: [title, detail])
        text.orientation = .vertical
        text.alignment = .leading
        text.spacing = 2
        let row = NSStackView(views: [text, button])
        row.orientation = .horizontal
        row.edgeInsets = NSEdgeInsets(top: 8, left: 10, bottom: 8, right: 10)
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            row.topAnchor.constraint(equalTo: topAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        isHidden = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    func show(_ banner: PaneBanner?) {
        switch banner {
        case nil:
            isHidden = true
        case .noAccess:
            isHidden = false
            title.stringValue = "Commander can't read this folder."
            detail.stringValue = "Grant Full Disk Access in System Settings → Privacy & Security."
            detail.isHidden = false
            button.isHidden = false
        case let .unreadable(message):
            isHidden = false
            title.stringValue = message
            detail.isHidden = true
            button.isHidden = true
        }
    }

    @objc private func openSettings() {
        NSWorkspace.shared.open(Self.privacySettings)
    }
}
