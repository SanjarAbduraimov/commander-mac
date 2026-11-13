import AppKit
import CommanderController
import CommanderCore
import SwiftUI

struct AppInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let url: URL
    let icon: NSImage
}

@MainActor
final class AppChooserPresenter {
    static func show(for urls: [URL], model: WindowModel, over window: NSWindow) {
        guard !urls.isEmpty else { return }
        let ext = urls.first?.pathExtension.lowercased() ?? ""

        // Discover applications capable of opening this file type
        var apps: [AppInfo] = []
        if let firstURL = urls.first {
            let appURLs = NSWorkspace.shared.urlsForApplications(toOpen: firstURL)
            for appURL in appURLs {
                let name = appURL.deletingPathExtension().lastPathComponent
                let icon = NSWorkspace.shared.icon(forFile: appURL.path)
                apps.append(AppInfo(id: appURL.path, name: name, url: appURL, icon: icon))
            }
        }

        // Also add standard apps if empty
        if apps.isEmpty {
            for defaultPath in ["/System/Applications/Preview.app", "/System/Applications/TextEdit.app", "/Applications/Visual Studio Code.app", "/Applications/Safari.app"] {
                let appURL = URL(fileURLWithPath: defaultPath)
                if FileManager.default.fileExists(atPath: defaultPath) {
                    let name = appURL.deletingPathExtension().lastPathComponent
                    let icon = NSWorkspace.shared.icon(forFile: defaultPath)
                    apps.append(AppInfo(id: defaultPath, name: name, url: appURL, icon: icon))
                }
            }
        }

        var sheetWindow: NSWindow?
        let view = AppChooserView(
            files: urls,
            extensionName: ext,
            apps: apps,
            onOpen: { selectedApp, alwaysAssociate in
                if let sheetWindow { window.endSheet(sheetWindow) }
                if alwaysAssociate, !ext.isEmpty {
                    var settings = model.settings
                    settings.setApp(selectedApp.url.path, forExtension: ext)
                    model.updateSettings(settings)
                }
                NSWorkspace.shared.open(urls, withApplicationAt: selectedApp.url, configuration: NSWorkspace.OpenConfiguration())
            },
            onCancel: {
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

struct AppChooserView: View {
    let files: [URL]
    let extensionName: String
    let apps: [AppInfo]
    let onOpen: (AppInfo, Bool) -> Void
    let onCancel: () -> Void

    @State private var selectedApp: AppInfo?
    @State private var customApps: [AppInfo] = []
    @State private var alwaysAssociate = false

    var allApps: [AppInfo] {
        customApps + apps
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Open With…")
                .font(.headline)

            let fileNames = files.prefix(3).map(\.lastPathComponent).joined(separator: ", ")
            let more = files.count > 3 ? " and \(files.count - 3) more" : ""
            Text("Choose an application to open \(fileNames)\(more):")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            List(allApps, selection: $selectedApp) { app in
                HStack(spacing: 10) {
                    Image(nsImage: app.icon)
                        .resizable()
                        .frame(width: 24, height: 24)
                    Text(app.name)
                        .font(.system(size: 13, weight: selectedApp == app ? .semibold : .regular))
                    Spacer()
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedApp = app
                }
                .tag(app)
            }
            .listStyle(.bordered)
            .frame(height: 180)

            HStack {
                Button("Other Application…") {
                    browseForApp()
                }
                Spacer()
            }

            if !extensionName.isEmpty {
                Toggle("Always open .\(extensionName) files with this application", isOn: $alwaysAssociate)
                    .font(.callout)
            }

            Divider()

            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Open") {
                    if let selected = selectedApp ?? allApps.first {
                        onOpen(selected, alwaysAssociate)
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedApp == nil && allApps.isEmpty)
            }
        }
        .padding(18)
        .frame(width: 440)
        .onAppear {
            selectedApp = allApps.first
        }
    }

    private func browseForApp() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.application]
        if panel.runModal() == .OK, let url = panel.url {
            let name = url.deletingPathExtension().lastPathComponent
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            let newApp = AppInfo(id: url.path, name: name, url: url, icon: icon)
            customApps.insert(newApp, at: 0)
            selectedApp = newApp
        }
    }
}
