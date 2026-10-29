import Foundation

/// Main-actor request state. Each begin/finish changes the generation so that
/// late ScreenCaptureKit results cannot revive a cancelled or timed-out session.
@MainActor
final class CaptureCoordinator {
    enum Phase: Equatable {
        case idle
        case capturing
        case showingFrozenFrame
    }

    private(set) var phase: Phase = .idle
    private(set) var generation: UInt64 = 0

    func beginCaptureRequest() -> Bool {
        guard phase == .idle else { return false }
        generation &+= 1
        phase = .capturing
        return true
    }

    func recordCapturedFrame(for request: UInt64) -> Bool {
        guard generation == request, phase == .capturing else { return false }
        phase = .showingFrozenFrame
        return true
    }

    func recordFailure(for request: UInt64) -> Bool {
        guard generation == request, phase == .capturing else { return false }
        phase = .idle
        generation &+= 1
        return true
    }

    func finishCaptureRequest() {
        phase = .idle
        generation &+= 1
    }
}
