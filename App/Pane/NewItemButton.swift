import AppKit
import CommanderController
import CommanderCore

@MainActor
final class NewItemButton: NSView {
    var onNewFolder: (() -> Void)?
    var onNewFile: (() -> Void)?
    var onNewTextDocument: (() -> Void)?
    var onNewMarkdownDocument: (() -> Void)?
    var onPasteImage: (() -> Void)?

    private let mainButton = NSButton(frame: .zero)
    private let dropdownButton = NSButton(frame: .zero)

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 5
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 0
        stack.alignment = .centerY
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightAnchor.constraint(equalToConstant: 22),
        ])

        // Main action button: "+ New"
        mainButton.title = " New"
        if let plus = NSImage(systemSymbolName: "plus", accessibilityDescription: "New") {
            let config = NSImage.SymbolConfiguration(pointSize: 10, weight: .semibold)
            mainButton.image = plus.withSymbolConfiguration(config)
            mainButton.imagePosition = .imageLeading
        }
        mainButton.isBordered = false
        mainButton.font = .systemFont(ofSize: 11, weight: .medium)
        mainButton.target = self
        mainButton.action = #selector(mainClicked)
        mainButton.setAccessibilityLabel("New Folder")
        stack.addArrangedSubview(mainButton)

        // Subtle vertical separator between button and dropdown arrow
        let sep = NSBox()
        sep.boxType = .separator
        sep.widthAnchor.constraint(equalToConstant: 1).isActive = true
        sep.heightAnchor.constraint(equalToConstant: 14).isActive = true
        stack.addArrangedSubview(sep)

        // Dropdown arrow button
        if let chevron = NSImage(systemSymbolName: "chevron.down", accessibilityDescription: "More options") {
            let config = NSImage.SymbolConfiguration(pointSize: 8, weight: .bold)
            dropdownButton.image = chevron.withSymbolConfiguration(config)
        } else {
            dropdownButton.title = "▾"
        }
        dropdownButton.isBordered = false
        dropdownButton.target = self
        dropdownButton.action = #selector(dropdownClicked)
        dropdownButton.widthAnchor.constraint(equalToConstant: 16).isActive = true
        stack.addArrangedSubview(dropdownButton)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    @objc private func mainClicked() {
        onNewFolder?()
    }

    @objc private func dropdownClicked() {
        let menu = NSMenu(title: "New Item")

        let folderItem = NSMenuItem(title: "Folder (F7)", action: #selector(menuNewFolder), keyEquivalent: "")
        if let icon = NSImage(systemSymbolName: "folder.fill", accessibilityDescription: nil) {
            folderItem.image = icon.withSymbolConfiguration(NSImage.SymbolConfiguration(hierarchicalColor: .systemBlue))
        }
        folderItem.target = self
        menu.addItem(folderItem)

        let fileItem = NSMenuItem(title: "Empty File (⌘N)", action: #selector(menuNewFile), keyEquivalent: "")
        if let icon = NSImage(systemSymbolName: "doc.fill", accessibilityDescription: nil) {
            fileItem.image = icon.withSymbolConfiguration(NSImage.SymbolConfiguration(hierarchicalColor: .secondaryLabelColor))
        }
        fileItem.target = self
        menu.addItem(fileItem)

        let txtItem = NSMenuItem(title: "Text Document (.txt)", action: #selector(menuNewTextDoc), keyEquivalent: "")
        if let icon = NSImage(systemSymbolName: "doc.text.fill", accessibilityDescription: nil) {
            txtItem.image = icon.withSymbolConfiguration(NSImage.SymbolConfiguration(hierarchicalColor: .systemCyan))
        }
        txtItem.target = self
        menu.addItem(txtItem)

        let mdItem = NSMenuItem(title: "Markdown File (.md)", action: #selector(menuNewMarkdownDoc), keyEquivalent: "")
        if let icon = NSImage(systemSymbolName: "doc.richtext.fill", accessibilityDescription: nil) {
            mdItem.image = icon.withSymbolConfiguration(NSImage.SymbolConfiguration(hierarchicalColor: .systemOrange))
        }
        mdItem.target = self
        menu.addItem(mdItem)

        menu.addItem(NSMenuItem.separator())

        let pasteItem = NSMenuItem(title: "Paste Image from Clipboard (⌘V)", action: #selector(menuPasteImage), keyEquivalent: "")
        if let icon = NSImage(systemSymbolName: "doc.on.clipboard.fill", accessibilityDescription: nil) {
            pasteItem.image = icon.withSymbolConfiguration(NSImage.SymbolConfiguration(hierarchicalColor: .systemPurple))
        }
        pasteItem.target = self
        menu.addItem(pasteItem)

        let point = NSPoint(x: 0, y: bounds.height + 4)
        menu.popUp(positioning: nil, at: point, in: self)
    }

    @objc private func menuNewFolder() { onNewFolder?() }
    @objc private func menuNewFile() { onNewFile?() }
    @objc private func menuNewTextDoc() { onNewTextDocument?() }
    @objc private func menuNewMarkdownDoc() { onNewMarkdownDocument?() }
    @objc private func menuPasteImage() { onPasteImage?() }
}
