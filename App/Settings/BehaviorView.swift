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
            Toggle("Restore tabs on launch", isOn: $model.behavior.restoreTabsOnLaunch)
        }
        .formStyle(.grouped)
    }
}
