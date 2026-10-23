import CommanderController
import Foundation
import NetFS

/// Mounts SMB shares through NetFS so macOS shows its own login dialog and reports where the share landed
/// (`NSWorkspace.open(smb://…)` would open a Finder window and never say).
struct NetFSMounter: ServerMounting {
    private static let userCancelled: Int32 = -128

    func mount(_ url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let openOptions = NSMutableDictionary()
            openOptions[kNAUIOptionKey] = kNAUIOptionAllowUI
            var requestID: AsyncRequestID?
            let started = NetFSMountURLAsync(url as CFURL, nil, nil, nil, openOptions, nil, &requestID, .main) { status, _, mountpoints in
                if let path = (mountpoints as? [String])?.first, status == 0 || status == EEXIST {
                    continuation.resume(returning: URL(fileURLWithPath: path, isDirectory: true))
                } else {
                    continuation.resume(throwing: Self.error(for: status))
                }
            }
            // A non-zero start means the report block will never run.
            if started != 0 { continuation.resume(throwing: Self.error(for: started)) }
        }
    }

    private static func error(for status: Int32) -> any Error {
        if status == ECANCELED || status == userCancelled { return CancellationError() }
        let domain = (1...ELAST).contains(status) ? NSPOSIXErrorDomain : NSOSStatusErrorDomain
        return NSError(domain: domain, code: Int(status))
    }
}
