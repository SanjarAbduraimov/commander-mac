import SwiftUI

struct ConnectToServerView: View {
    let recentServers: [String]
    let onConnect: (String) -> Void
    let onCancel: () -> Void

    @State private var address: String

    init(recentServers: [String], onConnect: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.recentServers = recentServers
        self.onConnect = onConnect
        self.onCancel = onCancel
        _address = State(initialValue: recentServers.first ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Server Address").font(.headline)
            TextField("smb://server/share", text: $address)
                .textFieldStyle(.roundedBorder)
                .onSubmit { connect() }
            if !recentServers.isEmpty {
                Text("Recent Servers").font(.subheadline).foregroundStyle(.secondary)
                List(recentServers, id: \.self) { server in
                    Text(server)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .onTapGesture { address = server }
                }
                .frame(height: 120)
            }
            HStack {
                Spacer()
                Button("Cancel", role: .cancel, action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Connect", action: connect)
                    .keyboardShortcut(.defaultAction)
                    .disabled(address.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 420)
    }

    private func connect() {
        onConnect(address)
    }
}
