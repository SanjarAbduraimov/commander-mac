import CommanderController
import CommanderCore
import SwiftUI

struct ShortcutsView: View {
    @Bindable var model: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Search Input
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                TextField("Search commands or shortcuts…", text: $model.shortcutQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                if !model.shortcutQuery.isEmpty {
                    Button {
                        model.shortcutQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(NSColor.separatorColor).opacity(0.4), lineWidth: 0.5)
            )

            // Shortcuts List Card
            SettingsCard {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(model.rows, id: \.command) { row in
                            HStack(spacing: 12) {
                                Text(row.title)
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundStyle(.primary)

                                if row.isCustom {
                                    Text("custom")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(Color.accentColor)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1)
                                        .background(Color.accentColor.opacity(0.12))
                                        .clipShape(Capsule())
                                }

                                Spacer()

                                if model.recording == row.command {
                                    ShortcutRecorder(onChord: model.record, onCancel: model.cancelRecording)
                                        .frame(width: 140, height: 22)
                                } else {
                                    Button {
                                        model.startRecording(row.command)
                                    } label: {
                                        Text(row.chords.isEmpty ? "—" : row.chords.map(\.displayString).joined(separator: "  "))
                                            .font(.system(size: 11, weight: .medium).monospaced())
                                            .foregroundStyle(row.chords.isEmpty ? .secondary : .primary)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color(NSColor.quaternaryLabelColor).opacity(0.2))
                                            .clipShape(RoundedRectangle(cornerRadius: 5))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)

                            if row.command != model.rows.last?.command {
                                Divider().opacity(0.25)
                            }
                        }
                    }
                }
                .frame(height: 240)
            }

            // Footer / Conflict Warning / Reset Defaults
            HStack {
                if let conflict = model.pendingConflict {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)
                    Text(conflict.message)
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)
                    Spacer()
                    Button("Cancel", action: model.cancelPendingAssignment)
                        .controlSize(.small)
                    Button("Assign Anyway", action: model.confirmPendingAssignment)
                        .controlSize(.small)
                        .buttonStyle(.borderedProminent)
                } else {
                    Text("Duplicates are detected before assigning.")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Button("Restore defaults", action: model.restoreShortcutDefaults)
                        .buttonStyle(.borderless)
                        .font(.system(size: 12))
                        .controlSize(.small)
                }
            }
        }
    }
}
