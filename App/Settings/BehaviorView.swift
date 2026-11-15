import CommanderController
import CommanderCore
import SwiftUI

struct BehaviorView: View {
    @Bindable var model: SettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsCard("Navigation & Keys") {
                SettingsRow(title: "Backspace key", subtitle: "Action when pressing Backspace in file list") {
                    Picker("", selection: $model.behavior.backspaceAction) {
                        Text("Parent folder").tag(BackspaceAction.parent)
                        Text("Go back in history").tag(BackspaceAction.historyBack)
                    }
                    .frame(width: 180)
                }

                Divider().opacity(0.3)

                SettingsRow(title: "Spacebar selection", subtitle: "Cursor movement after marking a file") {
                    Picker("", selection: $model.behavior.spaceAdvances) {
                        Text("Move to next row").tag(true)
                        Text("Stay on row").tag(false)
                    }
                    .frame(width: 180)
                }

                Divider().opacity(0.3)

                SettingsRow(title: "Forward Delete", subtitle: "Fn + ⌫ or external Delete key moves item to Trash") {
                    Toggle("", isOn: $model.behavior.forwardDeleteTrashes)
                        .labelsHidden()
                }
            }

            SettingsCard("File Operations") {
                SettingsRow(title: "Copy & move", subtitle: "Behavior when transferring files to opposite pane") {
                    Picker("", selection: $model.behavior.askDestinationForCopyMove) {
                        Text("Start immediately").tag(false)
                        Text("Ask destination").tag(true)
                    }
                    .frame(width: 180)
                }

                Divider().opacity(0.3)

                SettingsRow(title: "Hidden files", subtitle: "Show dotfiles and hidden system items by default") {
                    Toggle("", isOn: $model.behavior.showHiddenByDefault)
                        .labelsHidden()
                }
            }

            SettingsCard("Startup") {
                SettingsRow(title: "On launch", subtitle: "Folders to open when Commander starts") {
                    Picker("", selection: $model.behavior.restoreTabsOnLaunch) {
                        Text("Restore last session").tag(true)
                        Text("Open specific folders").tag(false)
                    }
                    .frame(width: 180)
                }

                if !model.behavior.restoreTabsOnLaunch {
                    Divider().opacity(0.3)
                    LaunchFolderRow(title: "Left pane", folder: $model.behavior.launchLeftFolder)
                    Divider().opacity(0.3)
                    LaunchFolderRow(title: "Right pane", folder: $model.behavior.launchRightFolder)
                }
            }
        }
    }
}

/// An empty folder means Home.
private struct LaunchFolderRow: View {
    let title: String
    @Binding var folder: URL?

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.primary)

            Spacer()

            Text(folder?.path ?? "Home")
                .font(.system(size: 12))
                .foregroundStyle(folder == nil ? .secondary : .primary)
                .lineLimit(1)
                .truncationMode(.head)
                .frame(maxWidth: 160, alignment: .trailing)

            Button("Choose…", action: choose)
                .buttonStyle(.bordered)
                .controlSize(.small)

            if folder != nil {
                Button("Clear") { folder = nil }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func choose() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK {
            folder = panel.url
        }
    }
}
