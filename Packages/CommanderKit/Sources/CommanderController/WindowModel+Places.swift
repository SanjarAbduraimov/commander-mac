import CommanderCore
import CommanderFileSystem
import Foundation

extension WindowModel {
    public var recentServers: [String] { session.recentServers }
    public var sidebarWidth: Double { session.sidebarWidth }

    public func setSidebarWidth(_ width: Double) {
        session.sidebarWidth = width
        publishSession()
    }

    public func openPlace(_ url: URL) {
        navigate(state.activeSide, to: url)
    }

    public func eject(_ volume: VolumeInfo) async {
        do {
            try await environment.ejectVolume(volume.url)
        } catch {
            effects.showAlert(AlertMessage(title: "Couldn't eject “\(volume.name)”", detail: error.localizedDescription))
            return
        }
        await sidebar.refreshVolumes()
        let volumePath = volume.url.standardizedFileURL.pathComponents
        for side in [PaneSide.left, .right] where tab(side).path.standardizedFileURL.pathComponents.starts(with: volumePath) {
            reload(side)
        }
    }

    public func connect(to address: String) async {
        guard let url = SMBAddress.normalize(address) else {
            effects.showAlert(AlertMessage(title: "Invalid server address", detail: "Enter an address like smb://server/share."))
            return
        }
        do {
            let mountPoint = try await environment.mounter.mount(url)
            // session.json is plain text; the password stays with the mount (and the Keychain, if the user saved it).
            var remembered = URLComponents(url: url, resolvingAgainstBaseURL: false)
            remembered?.password = nil
            session.addRecentServer(remembered?.url?.absoluteString ?? url.absoluteString)
            openPlace(mountPoint)
            await sidebar.refreshVolumes()
            publishSession()
        } catch is CancellationError {
            return
        } catch {
            effects.showAlert(AlertMessage(title: "Couldn't connect to “\(url.host ?? address)”", detail: error.localizedDescription))
        }
    }
}
