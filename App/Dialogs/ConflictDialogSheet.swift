import AppKit
import CommanderController
import CommanderCore
import SwiftUI

@MainActor
public final class ConflictPresenter {
    public static func show(for conflict: Conflict, over window: NSWindow) async -> ConflictResolution {
        await withCheckedContinuation { continuation in
            var sheetWindow: NSWindow?
            let view = ConflictDialogView(
                conflict: conflict,
                onResolve: { resolution in
                    if let sheetWindow { window.endSheet(sheetWindow) }
                    continuation.resume(returning: resolution)
                }
            )
            let hosting = NSHostingController(rootView: view)
            let sheet = NSWindow(contentViewController: hosting)
            sheet.styleMask = [.titled]
            sheetWindow = sheet
            window.beginSheet(sheet)
        }
    }
}

struct ConflictDialogView: View {
    let conflict: Conflict
    let onResolve: (ConflictResolution) -> Void

    @State private var applyToAll = false

    private var details: ConflictDetails? {
        conflict.details
    }

    private var canResume: Bool {
        guard let d = details else { return false }
        return d.targetSize > 0 && d.targetSize < d.sourceSize
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(details?.isDirectory == true ? "Folder Already Exists" : "File Already Exists")
                        .font(.headline)
                    Text("“\(conflict.existing.lastPathComponent)” already exists in this location.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            // Side-by-side comparison
            HStack(spacing: 14) {
                // Existing / Target
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(details?.isDirectory == true ? "Existing Folder (Destination)" : "Existing File (Destination)")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Spacer()
                        if let d = details {
                            if !d.isSourceNewer && d.sourceModified != d.targetModified {
                                Text("Newer")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.green.opacity(0.15))
                                    .foregroundStyle(.green)
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(conflict.existing.lastPathComponent)
                            .font(.body.bold())
                            .lineLimit(1)
                        if let d = details {
                            if d.isDirectory {
                                Text("Kind: Folder")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Size: \(ByteCountFormatter.string(fromByteCount: d.targetSize, countStyle: .file)) (\(d.targetSize) bytes)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text("Modified: \(DateFormatter.localizedString(from: d.targetModified, dateStyle: .medium, timeStyle: .short))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(NSColor.separatorColor), lineWidth: 0.5))
                }

                // New / Source
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(details?.isDirectory == true ? "New Folder (Source)" : "New File (Source)")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Spacer()
                        if let d = details {
                            if d.isSourceNewer {
                                Text("Newer")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.green.opacity(0.15))
                                    .foregroundStyle(.green)
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(conflict.source.lastPathComponent)
                            .font(.body.bold())
                            .lineLimit(1)
                        if let d = details {
                            if d.isDirectory {
                                Text("Kind: Folder")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Size: \(ByteCountFormatter.string(fromByteCount: d.sourceSize, countStyle: .file)) (\(d.sourceSize) bytes)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text("Modified: \(DateFormatter.localizedString(from: d.sourceModified, dateStyle: .medium, timeStyle: .short))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(NSColor.separatorColor), lineWidth: 0.5))
                }
            }

            // Apply to all checkbox
            Toggle("Apply to all remaining conflicts in this operation", isOn: $applyToAll)
                .font(.subheadline)
                .padding(.vertical, 2)

            Divider()

            // Action Buttons
            HStack(spacing: 8) {
                Button("Cancel") {
                    onResolve(ConflictResolution(decision: .skip, applyToAll: false))
                }
                .keyboardShortcut(.cancelAction)

                Button("Skip") {
                    onResolve(ConflictResolution(decision: .skip, applyToAll: applyToAll))
                }

                Spacer()

                Button("Auto-Rename") {
                    onResolve(ConflictResolution(decision: .keepBoth, applyToAll: applyToAll))
                }

                if canResume {
                    Button("Resume") {
                        onResolve(ConflictResolution(decision: .resume, applyToAll: applyToAll))
                    }
                }

                if details?.isSourceNewer == true {
                    Button("If Older") {
                        onResolve(ConflictResolution(decision: .replaceIfOlder, applyToAll: applyToAll))
                    }
                }

                if details?.hasSizeDifference == true {
                    Button("If Size Differs") {
                        onResolve(ConflictResolution(decision: .replaceIfSizeDiffers, applyToAll: applyToAll))
                    }
                }

                Button("Replace") {
                    onResolve(ConflictResolution(decision: .replace, applyToAll: applyToAll))
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(minWidth: 540)
    }
}
