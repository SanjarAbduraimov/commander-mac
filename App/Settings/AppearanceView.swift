import AppKit
import CommanderController
import CommanderCore
import SwiftUI

struct AppearanceView: View {
    @Bindable var model: SettingsViewModel
    let singlePane: Binding<Bool>
    private let families = NSFontManager.shared.availableFontFamilies

    var body: some View {
        Form {
            Picker("Theme", selection: $model.appearance.theme) {
                Text("System").tag(Theme.system)
                Text("Light").tag(Theme.light)
                Text("Dark").tag(Theme.dark)
            }
            .pickerStyle(.segmented)
            Toggle("Single pane", isOn: singlePane)

            Picker("File name", selection: $model.appearance.fontName) {
                Text("System").tag(String?.none)
                ForEach(families, id: \.self) { Text($0).tag(String?.some($0)) }
            }
            slider("Font size", value: $model.appearance.fontSize, range: 11...18)
            slider("Icon size", value: $model.appearance.iconSize, range: 12...32)
            slider("Row height", value: $model.appearance.rowHeight, range: 18...36)

            Section("Live preview") {
                ForEach(["Documents", "report.pdf", "notes.txt"], id: \.self) { name in
                    HStack(spacing: 6) {
                        Image(nsImage: NSWorkspace.shared.icon(for: name.contains(".") ? .data : .folder))
                            .resizable()
                            .frame(width: model.appearance.iconSize, height: model.appearance.iconSize)
                        Text(name).font(previewFont)
                        Spacer()
                    }
                    .frame(height: model.appearance.rowHeight)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var previewFont: Font {
        model.appearance.fontName.map { .custom($0, size: model.appearance.fontSize) } ?? .system(size: model.appearance.fontSize)
    }

    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        HStack {
            Slider(value: value, in: range, step: 1) { Text(title) }
            Text("\(Int(value.wrappedValue))").monospacedDigit().frame(width: 28, alignment: .trailing)
        }
    }
}
