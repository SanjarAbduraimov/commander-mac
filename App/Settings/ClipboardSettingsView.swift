import CommanderController
import CommanderCore
import SwiftUI

struct ClipboardSettingsView: View {
    @Bindable var model: SettingsViewModel

    var body: some View {
        Form {
            Section("Image Paste (Telegram-style)") {
                Toggle("Confirm before pasting image from clipboard", isOn: $model.clipboard.confirmPasteImage)
                    .help("When enabled, shows a preview dialog allowing you to name the image before saving.")

                Picker("Default image format", selection: $model.clipboard.defaultImageFormat) {
                    Text("PNG (lossless)").tag("png")
                    Text("JPEG (compressed)").tag("jpeg")
                    Text("TIFF (raw)").tag("tiff")
                }

                TextField("File naming pattern", text: $model.clipboard.imageNamingPattern)
                    .help("Date format tokens like yyyy, MM, dd, HH, mm, ss")
            }

            Section("Instructions") {
                Text("Copy any image or screenshot (e.g. from Chrome, Safari, or Telegram), then press ⌘V in Commander to paste it as an image file directly into the current folder.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
