import AppKit
import CommanderController
import CommanderCore
import SwiftUI

@MainActor
public final class TransferManagerPresenter {
    public static func show(model: WindowModel, over window: NSWindow) {
        var sheetWindow: NSWindow?
        let view = TransferManagerView(
            model: model,
            onDismiss: {
                if let sheetWindow { window.endSheet(sheetWindow) }
            }
        )
        let hosting = NSHostingController(rootView: view)
        let sheet = NSWindow(contentViewController: hosting)
        sheet.styleMask = [.titled]
        sheetWindow = sheet
        window.beginSheet(sheet)
    }
}

struct TransferManagerView: View {
    let model: WindowModel
    let onDismiss: () -> Void

    @State private var operations: [OperationState] = []
    @State private var timer = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "arrow.left.arrow.right.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Background Transfer Manager")
                        .font(.headline)
                    Text("Manage active, queued, and completed operations.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !operations.isEmpty {
                    Button("Cancel All") {
                        model.operations.cancelAll()
                        refresh()
                    }
                    .buttonStyle(.bordered)
                    .foregroundStyle(.red)
                }
            }

            Divider()

            // List of transfers
            if operations.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)
                    Text("No active background transfers")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 180)
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(operations) { op in
                            OperationCard(op: op) {
                                model.operations.cancel(op.id)
                                refresh()
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 300)
            }

            Divider()

            // Footer
            HStack {
                Spacer()
                Button("Done") {
                    onDismiss()
                }
                .keyboardShortcut(.defaultAction)
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(minWidth: 520)
        .onAppear { refresh() }
        .onReceive(timer) { _ in refresh() }
    }

    private func refresh() {
        operations = model.operations.operations
    }
}

private struct OperationCard: View {
    let op: OperationState
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: iconName(for: op.kind))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(iconColor(for: op.kind))

                Text(title(for: op.kind))
                    .font(.body.bold())

                if let current = op.progress.currentName, !current.isEmpty {
                    Text("— \(current)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    onCancel()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Cancel Operation")
            }

            // Progress bar
            ProgressView(value: progressFraction)
                .progressViewStyle(.linear)

            // Progress text
            HStack {
                if op.progress.totalBytes > 0 {
                    let done = ByteCountFormatter.string(fromByteCount: op.progress.completedBytes, countStyle: .file)
                    let total = ByteCountFormatter.string(fromByteCount: op.progress.totalBytes, countStyle: .file)
                    Text("\(done) of \(total)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(op.progress.completedFiles) of \(max(1, op.progress.totalFiles)) items")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if op.status == .waitingForUser {
                    Text("Waiting for input…")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(NSColor.separatorColor), lineWidth: 0.5))
    }

    private var progressFraction: Double {
        if op.progress.totalBytes > 0 {
            return Double(op.progress.completedBytes) / Double(op.progress.totalBytes)
        } else if op.progress.totalFiles > 0 {
            return Double(op.progress.completedFiles) / Double(op.progress.totalFiles)
        }
        return 0.0
    }

    private func iconName(for kind: OperationKind) -> String {
        switch kind {
        case .copy: return "doc.on.doc.fill"
        case .move: return "arrow.right.doc.on.clipboard"
        case .trash: return "trash.fill"
        case .delete: return "xmark.bin.fill"
        }
    }

    private func iconColor(for kind: OperationKind) -> Color {
        switch kind {
        case .copy: return .blue
        case .move: return .purple
        case .trash: return .red
        case .delete: return .red
        }
    }

    private func title(for kind: OperationKind) -> String {
        switch kind {
        case .copy: return "Copying"
        case .move: return "Moving"
        case .trash: return "Trashing"
        case .delete: return "Deleting"
        }
    }
}
