import AppKit
import CommanderController
import CommanderCore
import SwiftUI

struct FileAssociationsView: View {
    @Bindable var model: SettingsViewModel
    @State private var newExtension = ""
    @State private var selectedExtension: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Configure which application opens specific file extensions when pressing Enter or double-clicking.")
                .font(.callout)
                .foregroundStyle(.secondary)

            List(selection: $selectedExtension) {
                if model.fileAssociations.isEmpty {
                    Text("No custom associations set. macOS defaults will be used.")
                        .foregroundStyle(.tertiary)
                        .italic()
                } else {
                    ForEach(sortedAssociations, id: \.key) { ext, appPath in
                        HStack {
                            Text(".\(ext)")
                                .fontWeight(.medium)
                                .frame(width: 80, alignment: .leading)
                            
                            let appName = (appPath as NSString).lastPathComponent.replacingOccurrences(of: ".app", with: "")
                            Text(appName)
                                .foregroundStyle(.primary)

                            Spacer()

                            Text(appPath)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .tag(ext)
                    }
                }
            }
            .listStyle(.bordered)
            .frame(height: 220)

            HStack(spacing: 8) {
                TextField("Extension (e.g. png, md, ts)", text: $newExtension)
                    .frame(width: 180)

                Button("Choose App & Add…") {
                    chooseAppAndAdd()
                }
                .disabled(cleanExt.isEmpty)

                Spacer()

                if let selected = selectedExtension {
                    Button("Remove", role: .destructive) {
                        model.removeFileAssociation(extension: selected)
                        selectedExtension = nil
                    }
                }
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
