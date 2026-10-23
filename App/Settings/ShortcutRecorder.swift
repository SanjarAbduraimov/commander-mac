import AppKit
import CommanderController
import CommanderCore
import SwiftUI

/// Captures the next key chord. It lives in the Settings window, where KeyRouter does not listen,
/// so the chord is recorded instead of running a command.
struct ShortcutRecorder: NSViewRepresentable {
    let onChord: (KeyChord) -> Void
    let onCancel: () -> Void

    func makeNSView(context: Context) -> RecorderView {
        let view = RecorderView()
        view.onChord = onChord
        view.onCancel = onCancel
        DispatchQueue.main.async { view.window?.makeFirstResponder(view) }
        return view
    }

    func updateNSView(_ view: RecorderView, context: Context) {
        view.onChord = onChord
        view.onCancel = onCancel
    }

    final class RecorderView: NSView {
        var onChord: ((KeyChord) -> Void)?
        var onCancel: (() -> Void)?

        override var acceptsFirstResponder: Bool { true }

        override func draw(_ dirtyRect: NSRect) {
            NSColor.controlAccentColor.withAlphaComponent(0.15).setFill()
            NSBezierPath(roundedRect: bounds, xRadius: 4, yRadius: 4).fill()
            let text = NSAttributedString(string: "Type a shortcut…", attributes: [
                .font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor,
            ])
            text.draw(at: NSPoint(x: 8, y: (bounds.height - text.size().height) / 2))
        }

        override func keyDown(with event: NSEvent) {
            if event.keyCode == 53, event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty {
                onCancel?()
                return
            }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            var modifiers: KeyChord.Modifiers = []
            if flags.contains(.control) { modifiers.insert(.control) }
            if flags.contains(.option) { modifiers.insert(.option) }
            if flags.contains(.shift) { modifiers.insert(.shift) }
            if flags.contains(.command) { modifiers.insert(.command) }
            if let chord = KeyChordMapper.chord(keyCode: event.keyCode, baseCharacters: event.characters(byApplyingModifiers: []), modifiers: modifiers) {
                onChord?(chord)
            }
        }

        // Without this, ⌘-chords would be offered to the menu bar before reaching keyDown.
        override func performKeyEquivalent(with event: NSEvent) -> Bool {
            guard window?.firstResponder === self else { return false }
            keyDown(with: event)
            return true
        }
    }
}
