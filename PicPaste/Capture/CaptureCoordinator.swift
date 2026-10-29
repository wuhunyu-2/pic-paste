import Foundation

/// P0-02 request gate. P0-03 will add permission/capture and cancellation states.
@MainActor
final class CaptureCoordinator {
    enum Phase: Equatable {
        case idle
        case awaitingPlaceholderDismissal
    }

    private(set) var phase: Phase = .idle

    /// Menu bar and global hotkey share this gate; only one request may be active.
    func beginCaptureRequest() -> Bool {
        guard phase == .idle else { return false }
        phase = .awaitingPlaceholderDismissal
        return true
    }

    func finishCaptureRequest() {
        phase = .idle
    }
}
