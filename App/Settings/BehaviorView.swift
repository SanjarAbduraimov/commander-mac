import CommanderController
import CommanderCore
import SwiftUI

struct BehaviorView: View {
    @Bindable var model: SettingsViewModel

    var body: some View {
        Form {
            Picker("Backspace", selection: $model.behavior.backspaceAction) {
                Text("Parent folder").tag(BackspaceAction.parent)
                Text("Go back in history").tag(BackspaceAction.historyBack)
            }
            Picker("After marking a file", selection: $model.behavior.spaceAdvances) {
                Text("Move to next row").tag(true)
                Text("Stay on the row").tag(false)
            }
            Picker("Copy & move to other pane", selection: $model.behavior.askDestinationForCopyMove) {
                Text("Start immediately").tag(false)
                Text("Ask for destination").tag(true)
            }
            Toggle(isOn: $model.behavior.forwardDeleteTrashes) {
                Text("Also use Forward Delete")
                Text("Fn + ⌫ or an external Delete key")
            }
            Toggle("Show hidden files by default", isOn: $model.behavior.showHiddenByDefault)
            Picker("On launch", selection: $model.behavior.restoreTabsOnLaunch) {
                Text("Restore last session").tag(true)
                Text("Open these folders").tag(false)
            }
            if !model.behavior.restoreTabsOnLaunch {
                LaunchFolderRow(title: "Left", folder: $model.behavior.launchLeftFolder)
                LaunchFolderRow(title: "Right", folder: $model.behavior.launchRightFolder)
            }
        }
        .formStyle(.grouped)
    }
}

/// An empty folder means Home.
private struct LaunchFolderRow: View {
    let title: String
    @Binding var folder: URL?

    var body: some View {
        LabeledContent(title) {
            HStack {
                Text(folder?.path ?? "Home")
                    .foregroundStyle(folder == nil ? .secondary : .primary)
                    .lineLimit(1)
                    .truncationMode(.head)
                Button("Choose…", action: choose)
                if folder != nil {
                    Button("Clear") { folder = nil }
                }
            }
        }
    }

    private func choose() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = folder
        if panel.runModal() == .OK, let url = panel.url { folder = url }
    }
}
