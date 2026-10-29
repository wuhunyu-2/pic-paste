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
        alert.begin { [weak self] _ in
            self?.capture.finishCaptureRequest()
        }
    }

    func reportHotkeyRegistrationFailure(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "全局截图快捷键注册失败"
        alert.informativeText = "\(error.localizedDescription)\n你仍可通过菜单栏打开截图入口。"
        alert.begin(completionHandler: nil)
    }
}
