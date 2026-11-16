import AppKit
import SwiftUI

@MainActor
enum TelegramSharing {
    static func share(urls: [URL], from view: NSView? = nil) {
        guard !urls.isEmpty else { return }

        // If single non-directory file, share directly without zipping or progress sheet
        if urls.count == 1 {
            let url = urls[0]
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), !isDir.boolValue {
                openTelegram(with: [url], from: view)
                return
            }
        }

        // Folder or multiple items: show visual Progress Sheet with Cancel capability
        let window = view?.window ?? NSApp.keyWindow
        let title = urls.count == 1
            ? "Preparing “\(urls[0].lastPathComponent)”"
            : "Preparing \(urls.count) items"
        let subtitle = urls.count == 1
            ? "Creating archive for Telegram…"
            : "Compressing items into archive…"

        var sheetWindow: NSWindow?
        var isCancelled = false
        var activeProcess: Process?

        let cancelHandler: @MainActor () -> Void = {
            isCancelled = true
            activeProcess?.terminate()
            if let sw = sheetWindow, let win = window {
                win.endSheet(sw)
            }
        }

        let progressView = TelegramProgressView(
            title: title,
            subtitle: subtitle,
            onCancel: cancelHandler
        )

        let hosting = NSHostingController(rootView: progressView)
        let sheet = NSWindow(contentViewController: hosting)
        sheet.styleMask = [.titled]
        sheetWindow = sheet

        if let window {
            window.beginSheet(sheet)
        }

        Task { @MainActor in
            let prepared = await prepareArchive(urls: urls) { proc in
                DispatchQueue.main.async {
                    activeProcess = proc
                }
            }

            if let sheetWindow, let window {
                window.endSheet(sheetWindow)
            }

            if isCancelled {
                if let first = prepared.first {
                    try? FileManager.default.removeItem(at: first.deletingLastPathComponent())
                }
                return
            }
            guard !prepared.isEmpty else { return }
            cleanStaleTempArchives()
            openTelegram(with: prepared, from: view)
        }
    }

    private static func cleanStaleTempArchives() {
        Task.detached(priority: .background) {
            let temp = FileManager.default.temporaryDirectory
            guard let contents = try? FileManager.default.contentsOfDirectory(at: temp, includingPropertiesForKeys: [.contentModificationDateKey]) else { return }
            let oneHourAgo = Date().addingTimeInterval(-3600)
            for url in contents where url.lastPathComponent.hasPrefix("CommanderTelegram_") {
                if let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate, date < oneHourAgo {
                    try? FileManager.default.removeItem(at: url)
                }
            }
        }
    }

    private static func prepareArchive(urls: [URL], onProcessSpawned: @escaping @Sendable (Process) -> Void) async -> [URL] {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("CommanderTelegram_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let zipName = urls.count == 1 ? "\(urls[0].lastPathComponent).zip" : "Archive_\(urls.count)_items.zip"
        let targetZip = tempDir.appendingPathComponent(zipName)

        return await Task.detached(priority: .userInitiated) { () -> [URL] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")

            if urls.count == 1 {
                process.arguments = ["-c", "-k", "--sequesterRsrc", "--keepParent", urls[0].path, targetZip.path]
                onProcessSpawned(process)
                try? process.run()
                process.waitUntilExit()
            } else {
                let staging = tempDir.appendingPathComponent("Archive")
                try? FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
                for url in urls {
                    let dest = staging.appendingPathComponent(url.lastPathComponent)
                    try? FileManager.default.copyItem(at: url, to: dest)
                }
                process.arguments = ["-c", "-k", "--sequesterRsrc", staging.path, targetZip.path]
                onProcessSpawned(process)
                try? process.run()
                process.waitUntilExit()
                try? FileManager.default.removeItem(at: staging)
            }

            if process.terminationStatus == 0, FileManager.default.fileExists(atPath: targetZip.path) {
                return [targetZip]
            }
            try? FileManager.default.removeItem(at: tempDir)
            return []
        }.value
    }

    private static func openTelegram(with urls: [URL], from view: NSView?) {
        let telegramApp = URL(fileURLWithPath: "/Applications/Telegram.app")
        if FileManager.default.fileExists(atPath: telegramApp.path) {
            Task {
                _ = try? await NSWorkspace.shared.open(urls, withApplicationAt: telegramApp, configuration: NSWorkspace.OpenConfiguration())
            }
        } else {
            let picker = NSSharingServicePicker(items: urls)
            if let view {
                picker.show(relativeTo: view.bounds, of: view, preferredEdge: .maxY)
            } else if let keyView = NSApp.keyWindow?.contentView {
                picker.show(relativeTo: .zero, of: keyView, preferredEdge: .minY)
            }
        }
    }
}

private struct TelegramProgressView: View {
    let title: String
    let subtitle: String
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                Image(systemName: "paperplane.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(Color(red: 0.16, green: 0.67, blue: 0.93))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 0)
            }

            ProgressView()
                .progressViewStyle(.linear)
                .controlSize(.small)

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(18)
        .frame(width: 340)
    }
}
