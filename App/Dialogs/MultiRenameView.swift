import AppKit
import CommanderController
import CommanderCore
import SwiftUI

@MainActor
final class MultiRenameState: ObservableObject {
    @Published var options = MultiRenameOptions()
    @Published var isWorking = false
    @Published var error: String?

    let request: MultiRenameRequest
    let model: WindowModel

    init(request: MultiRenameRequest, model: WindowModel) {
        self.request = request
        self.model = model
    }

    var rows: [MultiRenameRow] {
        MultiRename.preview(request.items, folderName: request.folder.lastPathComponent, existing: request.existing, options: options)
    }

    static func describe(_ problem: RenameProblem) -> String {
        switch problem {
        case .empty: "Empty name"
        case .invalidCharacter: "Contains “/” or “:”"
        case .exists: "Already exists"
        case .duplicate: "Used twice"
        case .invalidRegex: "Invalid regular expression"
        }
    }
}

struct MultiRenameView: View {
    @ObservedObject var state: MultiRenameState
    let onRename: () -> Void
    let onUndo: () -> Void
    let onCancel: () -> Void

    var body: some View {
        let rows = state.rows
        let changed = rows.filter(\.isChanged).count
        let hasProblems = rows.contains { $0.problem != nil }
        VStack(alignment: .leading, spacing: 12) {
            Text("Multi-Rename \(rows.count) \(rows.count == 1 ? "item" : "items")").font(.headline)
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
                GridRow {
                    Text("Name mask")
                    TextField("[N]", text: $state.options.nameMask)
                        .accessibilityIdentifier("multiRename.nameMask")
                    Text("Ext mask")
                    TextField("[E]", text: $state.options.extMask)
                        .frame(width: 90)
                        .accessibilityIdentifier("multiRename.extMask")
                }
                GridRow {
                    Text("Search for")
                    TextField("", text: $state.options.search)
                        .accessibilityIdentifier("multiRename.search")
                    Text("Replace")
                    TextField("", text: $state.options.replace)
                        .frame(width: 90)
                        .accessibilityIdentifier("multiRename.replace")
                }
                GridRow {
                    Text("")
                    HStack(spacing: 16) {
                        Toggle("Regex", isOn: $state.options.useRegex)
                        Toggle("Case sensitive", isOn: $state.options.caseSensitive)
                        Picker("Case", selection: $state.options.nameCase) {
                            ForEach(NameCase.allCases, id: \.self) { Text($0.title).tag($0) }
                        }
                        .frame(width: 180)
                    }
                    .gridCellColumns(3)
                }
                GridRow {
                    Text("Counter [C]")
                    HStack(spacing: 8) {
                        number("Start", $state.options.counterStart)
                        number("Step", $state.options.counterStep)
                        number("Digits", $state.options.counterDigits)
                    }
                    .gridCellColumns(3)
                }
            }
            Text("[N] name · [N2-5] / [N3-] part of name · [E] extension · [C] counter · [P] folder · [YMD] [Y] [M] [D] [hms] date")
                .font(.caption)
                .foregroundStyle(.secondary)

            List {
                ForEach(rows, id: \.item.name) { row in
                    HStack {
                        Text(row.item.name)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "arrow.right").foregroundStyle(.tertiary)
                        Text(row.newName)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(row.problem != nil ? .red : row.isChanged ? .primary : .secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier("multiRename.new.\(row.item.name)")
                            .accessibilityValue(row.newName)
                        if let problem = row.problem {
                            Text(MultiRenameState.describe(problem))
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .frame(height: 260)

            if let error = state.error {
                Text(error).foregroundStyle(.red)
            }
            HStack {
                if state.model.canUndoMultiRename {
                    Button("Undo Last", action: onUndo)
                        .disabled(state.isWorking)
                }
                Spacer()
                Button("Cancel", role: .cancel, action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button(changed == 1 ? "Rename 1 Item" : "Rename \(changed) Items", action: onRename)
                    .keyboardShortcut(.defaultAction)
                    .disabled(changed == 0 || hasProblems || state.isWorking)
                    .accessibilityIdentifier("multiRename.rename")
            }
        }
        .padding(20)
        .frame(width: 760)
    }

    private func number(_ title: String, _ value: Binding<Int>) -> some View {
        HStack(spacing: 4) {
            Text(title).foregroundStyle(.secondary)
            TextField(title, value: value, format: .number)
                .frame(width: 48)
            Stepper("", value: value, in: 0...999_999).labelsHidden()
        }
    }
}

/// Shows the Multi-Rename sheet; the window model does the renaming and the undo.
@MainActor
final class MultiRenamePresenter {
    private static var current: MultiRenamePresenter?

    private let state: MultiRenameState
    private var sheet: NSWindow?

    private init(request: MultiRenameRequest, model: WindowModel) {
        state = MultiRenameState(request: request, model: model)
    }

    static func show(_ request: MultiRenameRequest, model: WindowModel, over window: NSWindow) {
        guard current == nil else { return }
        let presenter = MultiRenamePresenter(request: request, model: model)
        let view = MultiRenameView(
            state: presenter.state,
            onRename: { presenter.rename() },
            onUndo: { presenter.undo() },
            onCancel: { presenter.close() }
        )
        let sheet = NSWindow(contentViewController: NSHostingController(rootView: view))
        presenter.sheet = sheet
        current = presenter
        window.beginSheet(sheet)
    }

    private func rename() {
        let rows = state.rows
        state.isWorking = true
        state.error = nil
        Task {
            let error = await state.model.applyMultiRename(rows, in: state.request)
            state.isWorking = false
            if let error { state.error = error } else { close() }
        }
    }

    private func undo() {
        state.isWorking = true
        Task {
            let message = await state.model.undoMultiRename()
            close()
            if let message {
                let alert = NSAlert()
                alert.messageText = "Multi-Rename was partly undone"
                alert.informativeText = message
                alert.runModal()
            }
        }
    }

    private func close() {
        if let sheet { sheet.sheetParent?.endSheet(sheet) }
        sheet = nil
        Self.current = nil
    }
}
