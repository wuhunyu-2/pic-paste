import AppKit

@MainActor
final class AppCoordinator {
    private let capture = CaptureCoordinator()
    private(set) var captureRequestCount = 0

    func requestCapture() {
        guard capture.beginCaptureRequest() else { return }
        captureRequestCount += 1

        // Real capture starts in P0-03. For P0-02 give observable evidence
        // of menu/hotkey delivery without launching two overlapping dialogs.
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "PicPaste 截图事件已接收"
        alert.informativeText = "屏幕捕获将在 P0-03 接入；当前只验证全局快捷键与菜单栏事件。"
        // The temporary P0-02 verification alert is modal. The request gate
        // stays active until dismissal, even if the nested event loop receives
        // another global shortcut.
        defer { capture.finishCaptureRequest() }
        _ = alert.runModal()
    }
}
