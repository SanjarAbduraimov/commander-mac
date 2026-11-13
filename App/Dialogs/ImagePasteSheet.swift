import AppKit
import CommanderController
import CommanderCore
import SwiftUI

@MainActor
final class ImagePastePresenter {
    static func show(image: NSImage, targetDirectory: URL, model: WindowModel, side: PaneSide, over window: NSWindow) {
        let pattern = model.settings.clipboard.imageNamingPattern
        let defaultFormat = model.settings.clipboard.defaultImageFormat
        let formatter = DateFormatter()
        formatter.dateFormat = pattern.isEmpty ? "yyyy-MM-dd_HHmmss" : pattern
        let baseName = "Image_\(formatter.string(from: Date()))"

        var sheetWindow: NSWindow?
        let view = ImagePasteView(
            image: image,
            initialName: "\(baseName).\(defaultFormat)",
            defaultFormat: defaultFormat,
            onSave: { fileName, format in
                if let sheetWindow { window.endSheet(sheetWindow) }
                saveImage(image, named: fileName, format: format, to: targetDirectory, model: model, side: side)
            },
            onCancel: {
                if let sheetWindow { window.endSheet(sheetWindow) }
            }
        )

        let hosting = NSHostingController(rootView: view)
        let sheet = NSWindow(contentViewController: hosting)
        sheet.styleMask = [.titled]
        sheetWindow = sheet
        window.beginSheet(sheet)
    }

    static func saveImage(
        _ image: NSImage, named requestedName: String, format: String,
        to directory: URL, model: WindowModel, side: PaneSide
    ) {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return }

        let fileType: NSBitmapImageRep.FileType = switch format.lowercased() {
        case "jpg", "jpeg": .jpeg
        case "tiff", "tif": .tiff
        default: .png
        }

        guard let data = bitmap.representation(using: fileType, properties: [:]) else { return }

        let cleanName = requestedName.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = cleanName.isEmpty ? "Image.png" : cleanName
        let destination = directory.appendingPathComponent(finalName)

        do {
            try data.write(to: destination, options: .atomic)
            model.reload(side)
            model.setCursor(side, name: finalName)
        } catch {
            let alert = NSAlert()
            alert.messageText = "Failed to paste image"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }
}

struct ImagePasteView: View {
    let image: NSImage
    let onSave: (String, String) -> Void
    let onCancel: () -> Void

    @State private var fileName: String
    @State private var format: String

    init(image: NSImage, initialName: String, defaultFormat: String, onSave: @escaping (String, String) -> Void, onCancel: @escaping () -> Void) {
        self.image = image
        self.onSave = onSave
        self.onCancel = onCancel
        _fileName = State(initialValue: initialName)
        _format = State(initialValue: defaultFormat)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Paste Image from Clipboard")
                .font(.headline)

            HStack {
                Spacer()
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 180)
                    .cornerRadius(8)
                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                Spacer()
            }
            .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 6) {
                Text("File Name:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("File Name", text: $fileName)
                    .textFieldStyle(.roundedBorder)
            }

            Picker("Format", selection: $format) {
                Text("PNG").tag("png")
                Text("JPEG").tag("jpeg")
                Text("TIFF").tag("tiff")
            }
            .pickerStyle(.segmented)
            .onChange(of: format) { _, newFormat in
                let stem = (fileName as NSString).deletingPathExtension
                fileName = "\(stem).\(newFormat)"
            }

            Divider()

            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Paste as File") {
                    onSave(fileName, format)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(fileName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(18)
        .frame(width: 380)
    }
}
