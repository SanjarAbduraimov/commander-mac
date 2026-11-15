import CommanderController
import CommanderCore
import SwiftUI

struct ClipboardSettingsView: View {
    @Bindable var model: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsCard("Image Paste (⌘V)") {
                SettingsRow(title: "Confirmation dialog", subtitle: "Show preview & name prompt before saving image") {
                    Toggle("", isOn: $model.clipboard.confirmPasteImage)
                        .labelsHidden()
                }

                Divider().opacity(0.3)

                SettingsRow(title: "Default image format", subtitle: "Output image container format") {
                    Picker("", selection: $model.clipboard.defaultImageFormat) {
                        Text("PNG (lossless)").tag("png")
                        Text("JPEG (compressed)").tag("jpeg")
                        Text("TIFF (raw)").tag("tiff")
                    }
                    .frame(width: 180)
                }

                Divider().opacity(0.3)

                SettingsRow(title: "Naming pattern", subtitle: "Date tokens: yyyy, MM, dd, HH, mm, ss") {
                    TextField("Pattern", text: $model.clipboard.imageNamingPattern)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 180)
                }
            }

            SettingsCard("How it works") {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Instant Clipboard Image Paste")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)

                        Text("Copy any image or screenshot from your web browser, Telegram, or Preview to your clipboard. Then focus any folder in Commander and press ⌘V to instantly paste it as an image file directly into that directory.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineSpacing(2)
                    }
                }
                .padding(14)
            }
        }
    }
}
