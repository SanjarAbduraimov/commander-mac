import AppKit
import CommanderController
import CommanderCore
import SwiftUI

struct FileAssociationsView: View {
    @Bindable var model: SettingsViewModel
    @State private var newExtension = ""
    @State private var selectedExtension: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsCard("Custom File Handlers") {
                if model.fileAssociations.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 6) {
                            Image(systemName: "app.badge.checkmark")
                                .font(.system(size: 24))
                                .foregroundStyle(.tertiary)
                            Text("No custom associations set")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                            Text("macOS system defaults will be used when opening files.")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 28)
                        Spacer()
                    }
                } else {
                    VStack(spacing: 0) {
                        ForEach(sortedAssociations, id: \.key) { ext, appPath in
                            let appName = (appPath as NSString).lastPathComponent.replacingOccurrences(of: ".app", with: "")
                            HStack(spacing: 12) {
                                Text(".\(ext)")
                                    .font(.system(size: 13, weight: .semibold).monospaced())
                                    .foregroundStyle(Color.accentColor)
                                    .frame(width: 70, alignment: .leading)

                                Text(appName)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.primary)

                                Spacer()

                                Text(appPath)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .frame(maxWidth: 180)

                                Button {
                                    model.removeFileAssociation(extension: ext)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.red.opacity(0.8))
                                }
                                .buttonStyle(.borderless)
                                .help("Remove association")
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)

                            if ext != sortedAssociations.last?.key {
                                Divider().opacity(0.3)
                            }
                        }
                    }
                }
            }

            SettingsCard("Add Association") {
                HStack(spacing: 10) {
                    TextField("Extension (e.g. pdf, md)", text: $newExtension)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 170)

                    Button("Choose App…") {
                        chooseAppAndAdd()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .disabled(cleanExt.isEmpty)

                    Spacer()
                }
                .padding(14)
            }
        }
    }

    private var sortedAssociations: [(key: String, value: String)] {
        model.fileAssociations.sorted { $0.key < $1.key }
    }

    private var cleanExt: String {
        newExtension.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: " ."))
    }

    private func chooseAppAndAdd() {
        let ext = cleanExt
        guard !ext.isEmpty else { return }

        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application]
        panel.prompt = "Set for .\(ext)"

        if panel.runModal() == .OK, let appURL = panel.url {
            model.setFileAssociation(extension: ext, appPath: appURL.path)
            newExtension = ""
        }
    }
}
