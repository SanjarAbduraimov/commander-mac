import AppKit
import SwiftUI

@MainActor
public final class DeleteConfirmPresenter {
    public static func show(
        over window: NSWindow,
        title: String,
        detail: String
    ) async -> Bool {
        await withCheckedContinuation { continuation in
            var sheetWindow: NSWindow?
            let stateHolder = DeleteConfirmState()

            let view = DeleteConfirmView(
                title: title,
                detail: detail,
                state: stateHolder,
                onConfirm: {
                    if let sheet = sheetWindow { window.endSheet(sheet) }
                    continuation.resume(returning: true)
                },
                onCancel: {
                    if let sheet = sheetWindow { window.endSheet(sheet) }
                    continuation.resume(returning: false)
                }
            )

            let hosting = NSHostingController(rootView: view)
            let sheet = NSWindow(contentViewController: hosting)
            sheet.styleMask = [.titled]
            sheetWindow = sheet

            var monitor: Any?
            let cleanup: () -> Void = {
                if let m = monitor {
                    NSEvent.removeMonitor(m)
                    monitor = nil
                }
            }

            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                nonisolated(unsafe) let event = event
                let consumed = MainActor.assumeIsolated {
                    guard event.window === sheet || event.window === window || event.window?.attachedSheet === sheet else { return false }

                    // Left Arrow (123) / Up Arrow (126) -> Cancel (0)
                    if event.keyCode == 123 || event.keyCode == 126 {
                        stateHolder.selectedIndex = 0
                        return true
                    }
                    // Right Arrow (124) / Down Arrow (125) -> Delete (1)
                    if event.keyCode == 124 || event.keyCode == 125 {
                        stateHolder.selectedIndex = 1
                        return true
                    }
                    // Tab (48) -> toggle
                    if event.keyCode == 48 {
                        stateHolder.selectedIndex = (stateHolder.selectedIndex == 0) ? 1 : 0
                        return true
                    }
                    // Return / Enter (36, 76) or Space (49)
                    if event.keyCode == 36 || event.keyCode == 76 || event.keyCode == 49 {
                        cleanup()
                        if stateHolder.selectedIndex == 0 {
                            if let s = sheetWindow { window.endSheet(s) }
                            continuation.resume(returning: false)
                        } else {
                            if let s = sheetWindow { window.endSheet(s) }
                            continuation.resume(returning: true)
                        }
                        return true
                    }
                    // Esc (53)
                    if event.keyCode == 53 {
                        cleanup()
                        if let s = sheetWindow { window.endSheet(s) }
                        continuation.resume(returning: false)
                        return true
                    }

                    return false
                }
                return consumed ? nil : event
            }

            window.beginSheet(sheet) { _ in
                cleanup()
            }
        }
    }
}

@MainActor
final class DeleteConfirmState: ObservableObject {
    @Published var selectedIndex: Int = 1 // Default to Delete (1)
}

private struct DeleteConfirmView: View {
    let title: String
    let detail: String
    @ObservedObject var state: DeleteConfirmState
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // macOS Warning Icon with app badge
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .symbolRenderingMode(.multicolor)
                    .font(.system(size: 48))

                if let appIcon = NSApp.applicationIconImage {
                    Image(nsImage: appIcon)
                        .resizable()
                        .frame(width: 22, height: 22)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        .shadow(radius: 2)
                        .offset(x: 4, y: 4)
                }
            }
            .padding(.top, 4)

            // Title and Details
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(detail)
                    .font(.system(size: 12, weight: .regular))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 12)

            // Action Buttons
            HStack(spacing: 14) {
                // Cancel Button
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.system(size: 13, weight: .medium))
                        .frame(minWidth: 88, minHeight: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.bordered)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(state.selectedIndex == 0 ? Color.accentColor : Color.clear, lineWidth: 2.5)
                        .padding(-2)
                )

                // Delete Button
                Button(action: onConfirm) {
                    Text("Delete")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(minWidth: 88, minHeight: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(state.selectedIndex == 1 ? Color.accentColor : Color.clear, lineWidth: 2.5)
                        .padding(-2)
                )
            }
            .padding(.top, 4)
        }
        .padding(24)
        .frame(width: 320)
    }
}
