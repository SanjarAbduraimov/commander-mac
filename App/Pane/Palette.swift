import AppKit

/// Colors from the design prototype (docs/design/prototype), light and dark.
enum Palette {
    static let accent = dynamic(light: 0x3F77D2, dark: 0x8BB4FB)
    static let cursorBackground = dynamic(light: 0xE9F1FF, dark: 0x334662)
    static let markedBackground = dynamic(light: 0xEEF4FF, dark: 0x2D3B51)
    static let markSymbol = NSColor(hex: 0x5B8BD6)

    private static func dynamic(light: Int, dark: Int) -> NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(hex: dark) : NSColor(hex: light)
        }
    }
}

extension NSColor {
    convenience init(hex: Int) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
