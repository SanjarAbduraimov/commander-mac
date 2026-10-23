import CommanderController
import CommanderCore
import SwiftUI

struct ShortcutsView: View {
    @Bindable var model: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Search commands or shortcuts", text: $model.shortcutQuery)
                .textFieldStyle(.roundedBorder)
            List(model.rows, id: \.command) { row in
                HStack {
                    Text(row.title)
                    if row.isCustom {
                        Text("custom").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if model.recording == row.command {
                        ShortcutRecorder(onChord: model.record, onCancel: model.cancelRecording)
                            .frame(width: 140, height: 22)
                    } else {
                        Button(row.chords.isEmpty ? "—" : row.chords.map(\.displayString).joined(separator: "  ")) {
                            model.startRecording(row.command)
                        }
                        .monospaced()
                    }
                }
            }
            HStack {
                if let conflict = model.pendingConflict {
                    Text(conflict.message).foregroundStyle(.orange)
                    Spacer()
                    Button("Cancel", action: model.cancelPendingAssignment)
                    Button("Assign Anyway", action: model.confirmPendingAssignment)
                } else {
                    Text("Duplicates are detected before a shortcut is assigned.").foregroundStyle(.secondary)
                    Spacer()
                    Button("Restore defaults", action: model.restoreShortcutDefaults)
                }
            }
            .font(.callout)
        }
    }
}
