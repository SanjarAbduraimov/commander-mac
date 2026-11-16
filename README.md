# Commander for Mac

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform: macOS 15+](https://img.shields.io/badge/Platform-macOS%2015.0%2B-lightgrey.svg)](https://apple.com/macos)
[![Swift: 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Tests: 381 passed](https://img.shields.io/badge/Tests-381%20passed-brightgreen.svg)]()

A modern, fast, dual-pane macOS file manager inspired by Total Commander. Built natively with **Swift** and **AppKit** for keyboard-centric power users.

---

## Features

- **Dual-Pane Navigation:** Two independent file panels with tabs (`⌘T`, `⌘W`), history back/forward (`⌘[`, `⌘]`), and seamless drag & drop.
- **Single / Dual Pane Toggle:** Switch effortlessly between single-pane and classic dual-pane mode (`⌘\`).
- **Quick View (`⌃Q` / `Esc`):** Instant preview panel in the inactive pane with image zoom & pan, code syntax highlighting, PDFs, media playback, and text files.
- **Background Transfer Queue:** High-throughput async file copying and moving with pause/resume, cancel, and conflict resolution (Overwrite, Skip, Keep Both, Rename).
- **Multi-Rename Tool (`⌘M` / `F2`):** Powerful batch renaming with search & replace, sequential numbering, uppercase/lowercase conversions, and live preview.
- **Fast Type-Ahead Search:** Instant search jumping with diacritic support and hidden file matching.
- **Clipboard Integration:** Standard Copy/Cut/Paste operations, plus **Clipboard Image Paste (`⌘V`)** to directly paste images copied from browsers or chat apps as PNG files.
- **In-App Modal Settings (`⌘,`):** Configure keybindings, behavior, theme, and file associations without leaving the workspace.
- **Undo / Redo (`⌘Z`, `⇧⌘Z`):** Revert file moves, copies, and batch renames safely.
- **Network Volumes:** Connect to remote SMB / AFP file servers directly from the sidebar.
- **Telegram Sharing:** Share files and folders directly via Telegram with background progress indicator and cancel support.
- **Native macOS 15 Visual Polish:** Pill selections, frosted glass header, chiclet shortcuts, spacious tabs, and interactive split divider.

---

## Keyboard Shortcuts

| Shortcut | Action |
| :--- | :--- |
| `Tab` | Switch active pane |
| `⌘\` | Toggle Single / Dual Pane |
| `⌃Q` / `Esc` | Toggle Quick View preview |
| `Space` | Quick Look preview / Toggle selection and advance |
| `⌘T` / `⌘W` | New Tab / Close Tab |
| `⌘[` / `⌘]` | History Back / Forward |
| `⌘B` | Toggle Sidebar |
| `F5` / `F6` | Copy / Move to opposite pane |
| `⌘C` / `⌘X` / `⌘V` | Copy / Cut / Paste |
| `⌘⌫` | Move to Trash |
| `⌥⌘⌫` | Delete immediately (permanent) |
| `⌘M` / `F2` | Batch Multi-Rename |
| `⌘,` | Open Settings |
| `⌘Z` / `⇧⌘Z` | Undo / Redo |

*All shortcuts can be fully customized in Settings (`⌘,`) under the **Shortcuts** tab.*

---

## Requirements

- **macOS:** macOS 15.0 (Sequoia) or newer (Universal: Apple Silicon & Intel x86_64 supported)
- **Xcode:** Xcode 16.0+ (with Command Line Tools)
- **XcodeGen:** `brew install xcodegen`

---

## Build and Run

Clone the repository:
```bash
git clone https://github.com/SanjarAbduraimov/commander-mac.git
cd commander-mac
```

Generate the Xcode project:
```bash
xcodegen generate
```

Build the application:
```bash
xcodebuild -project Commander.xcodeproj -scheme Commander -destination 'platform=macOS,arch=x86_64' build
```

Run test suite:
```bash
swift test --package-path Packages/CommanderKit
```

Package as Universal DMG (Release):
```bash
./scripts/make-dmg.sh
```
The output file will be generated at `build/Commander.dmg`.

---

## Architecture

The codebase follows a modular clean architecture:

- **`Packages/CommanderKit`**:
  - `CommanderCore`: Pure data models, keybindings engine, transfer models, settings persistence, independent of UI.
  - `CommanderFileSystem`: Async file operations, file conflict resolution, FSEvents directory watcher, volume resolution, stream copier.
  - `CommanderController`: State management, `WindowModel`, `OperationCenter`, undo stack. Unit-tested without AppKit/UI dependencies.
- **`App/`**:
  - Native AppKit application window, `NSTableView`, custom `ModernSplitView`, interactive tab bar, breadcrumb navigation, and modal sheets.
  - SwiftUI sheets for Settings (`SettingsWindowController`) and Transfer Manager.

---

## Contributing

Contributions, bug reports, and feature requests are welcome!

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Run tests (`swift test --package-path Packages/CommanderKit`)
5. Push to the Branch (`git push origin feature/AmazingFeature`)
6. Open a Pull Request

---

## License

Distributed under the **MIT License**. See [`LICENSE`](LICENSE) for more information.
