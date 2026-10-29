import AppKit

@MainActor
final class AppCoordinator {
    private(set) var captureRequestCount = 0

    func requestCapture() {
        // Issue #2 and #3 will connect the global hotkey and capture state machine.
        captureRequestCount += 1
        let alert = NSAlert()
        alert.messageText = "PicPaste"
        alert.informativeText = "截图功能将在后续 P0 任务中接入。"
        alert.runModal()
    }
}
