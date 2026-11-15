import AppKit
import CommanderController
import CommanderCore
import SwiftUI

struct AppearanceView: View {
    @Bindable var model: SettingsViewModel
    let singlePane: Binding<Bool>
    private let families = NSFontManager.shared.availableFontFamilies

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsCard("Theme & Layout") {
                SettingsRow(title: "Theme", subtitle: "Application interface color scheme") {
                    Picker("", selection: $model.appearance.theme) {
                        Text("System").tag(Theme.system)
                        Text("Light").tag(Theme.light)
                        Text("Dark").tag(Theme.dark)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)
                }

                Divider().opacity(0.3)

                SettingsRow(title: "Single pane", subtitle: "Show only active file list instead of dual panels") {
                    Toggle("", isOn: singlePane)
                        .labelsHidden()
                }
            }

            SettingsCard("Typography & Sizing") {
                SettingsRow(title: "File name font") {
                    Picker("", selection: $model.appearance.fontName) {
                        Text("System").tag(String?.none)
                        ForEach(families, id: \.self) { Text($0).tag(String?.some($0)) }
                    }
                    .frame(width: 180)
                }

                Divider().opacity(0.3)

                SettingsRow(title: "Font size") {
                    HStack(spacing: 8) {
                        Slider(value: $model.appearance.fontSize, in: 11...18, step: 1)
                            .frame(width: 140)
                        Text("\(Int(model.appearance.fontSize)) pt")
                            .font(.system(size: 12).monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 36, alignment: .trailing)
                    }
                }

                Divider().opacity(0.3)

                SettingsRow(title: "Icon size", subtitle: "Scales icons smoothly with uniform padding") {
                    HStack(spacing: 8) {
                        Slider(value: $model.appearance.iconSize, in: 12...32, step: 1)
                            .frame(width: 140)
                            .onChange(of: model.appearance.iconSize) { _, newSize in
                                if model.appearance.rowHeight < newSize + 4 {
                                    model.appearance.rowHeight = newSize + 4
                                }
                            }
                        Text("\(Int(model.appearance.iconSize)) px")
                            .font(.system(size: 12).monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 38, alignment: .trailing)
                    }
                }

                Divider().opacity(0.3)

                SettingsRow(title: "Row height", subtitle: "Vertical spacing for each row in file tables") {
                    HStack(spacing: 8) {
                        Slider(value: $model.appearance.rowHeight, in: 18...44, step: 1)
                            .frame(width: 140)
                        Text("\(Int(model.appearance.rowHeight)) pt")
                            .font(.system(size: 12).monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 38, alignment: .trailing)
                    }
                }
            }

            SettingsCard("Live Preview") {
                VStack(spacing: 0) {
                    ForEach(["Documents", "report.pdf", "notes.txt"], id: \.self) { name in
                        let isFolder = !name.contains(".")
                        let item = FileItem(
                            name: name,
                            url: URL(fileURLWithPath: "/preview/\(name)"),
                            kind: isFolder ? .directory : .file,
                            size: 1024,
                            modified: Date(),
                            isHidden: false
                        )
                        HStack(spacing: 8) {
                            Image(nsImage: IconCache.shared.icon(for: item, size: CGFloat(model.appearance.iconSize)))
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: model.appearance.iconSize, height: model.appearance.iconSize)
                            Text(name)
                                .font(previewFont)
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .frame(height: model.appearance.rowHeight)

                        if name != "notes.txt" {
                            Divider().opacity(0.2)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var previewFont: Font {
        model.appearance.fontName.map { .custom($0, size: model.appearance.fontSize) } ?? .system(size: model.appearance.fontSize)
    }
}
