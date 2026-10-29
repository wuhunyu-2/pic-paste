import CoreGraphics

/// Explicitly request the system's screen-capture permission, never bypass TCC.
@MainActor
final class ScreenPermissionService {
    func ensureAuthorized() throws {
        guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else {
            throw CaptureFailure.permissionDenied
        }
    }
}
