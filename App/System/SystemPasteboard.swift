import AppKit
import CommanderController

/// Files go on the general pasteboard so ⌘C/⌘V work with Finder both ways. A cut is only remembered while
/// the pasteboard still holds what we put there: copying anything else in between turns ⌘V back into a copy.
@MainActor
final class SystemPasteboard: FilePasteboard {
    private static let cutMarker = NSPasteboard.PasteboardType("local.sanjar.commander.cut")

    private let pasteboard = NSPasteboard.general
    private var cutChangeCount: Int?

    func writeFiles(_ urls: [URL], cut: Bool) {
        pasteboard.clearContents()
        pasteboard.writeObjects(urls as [NSURL])
        if cut {
            pasteboard.pasteboardItems?.first?.setData(Data(), forType: Self.cutMarker)
            cutChangeCount = pasteboard.changeCount
        } else {
            cutChangeCount = nil
        }
    }

    func writeString(_ string: String) {
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
        cutChangeCount = nil
    }

    func readFiles() -> (urls: [URL], isCut: Bool)? {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL], !urls.isEmpty else { return nil }
        let markerPresent = pasteboard.pasteboardItems?.first?.types.contains(Self.cutMarker) ?? false
        return (urls, markerPresent && cutChangeCount == pasteboard.changeCount)
    }

    func clearCut() {
        cutChangeCount = nil
    }

    func hasImage() -> Bool {
        if NSImage.canInit(with: pasteboard) { return true }
        let imageTypes = [
            NSPasteboard.PasteboardType.png,
            NSPasteboard.PasteboardType.tiff,
            NSPasteboard.PasteboardType("public.png"),
            NSPasteboard.PasteboardType("public.jpeg"),
            NSPasteboard.PasteboardType("public.image"),
        ]
        return pasteboard.availableType(from: imageTypes) != nil
    }
}
