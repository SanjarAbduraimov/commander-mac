import AppKit

@MainActor
enum TelegramSharing {
    static func share(urls: [URL], from view: NSView? = nil) {
        guard !urls.isEmpty else { return }

        Task { @MainActor in
            let prepared = await prepareURLsForTelegram(urls: urls)
            guard !prepared.isEmpty else { return }

            let telegramApp = URL(fileURLWithPath: "/Applications/Telegram.app")
            if FileManager.default.fileExists(atPath: telegramApp.path) {
                _ = try? await NSWorkspace.shared.open(prepared, withApplicationAt: telegramApp, configuration: NSWorkspace.OpenConfiguration())
            } else {
                let picker = NSSharingServicePicker(items: prepared)
                if let view {
                    picker.show(relativeTo: view.bounds, of: view, preferredEdge: .maxY)
                } else if let keyView = NSApp.keyWindow?.contentView {
                    picker.show(relativeTo: .zero, of: keyView, preferredEdge: .minY)
                }
            }
        }
    }

    private static func prepareURLsForTelegram(urls: [URL]) async -> [URL] {
        // If single non-directory file, share directly without zipping
        if urls.count == 1 {
            let url = urls[0]
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), !isDir.boolValue {
                return [url]
            }
        }

        // Folder or multiple files/folders: auto-zip into temporary archive
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("CommanderTelegram_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let zipName: String
        if urls.count == 1 {
            zipName = "\(urls[0].lastPathComponent).zip"
        } else {
            zipName = "Archive_\(urls.count)_items.zip"
        }
        let targetZip = tempDir.appendingPathComponent(zipName)

        return await Task.detached(priority: .userInitiated) { () -> [URL] in
            if urls.count == 1 {
                // Single folder/package
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
                process.arguments = ["-c", "-k", "--sequesterRsrc", "--keepParent", urls[0].path, targetZip.path]
                try? process.run()
                process.waitUntilExit()
            } else {
                // Multiple items: stage into temporary folder and zip
                let staging = tempDir.appendingPathComponent("Archive")
                try? FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
                for url in urls {
                    let dest = staging.appendingPathComponent(url.lastPathComponent)
                    try? FileManager.default.copyItem(at: url, to: dest)
                }
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
                process.arguments = ["-c", "-k", "--sequesterRsrc", staging.path, targetZip.path]
                try? process.run()
                process.waitUntilExit()
                try? FileManager.default.removeItem(at: staging)
            }

            if FileManager.default.fileExists(atPath: targetZip.path) {
                return [targetZip]
            }
            return urls
        }.value
    }
}
