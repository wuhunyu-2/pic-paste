import AppKit

@MainActor
final class AppCoordinator {
    private let capture = CaptureCoordinator()
    private let captureService = CaptureService()
    private var captureTask: Task<Void, Never>?
    private var deadlineTask: Task<Void, Never>?
    private var activeRequestID: UInt64?
    private var presentingFeedback = false

    private(set) var captureRequestCount = 0

    func requestCapture() {
        guard !presentingFeedback, capture.beginCaptureRequest() else { return }
        captureRequestCount += 1

        let requestID = capture.generation
        activeRequestID = requestID

        captureTask = Task { [weak self] in
            guard let self else { return }
            defer {
                if self.activeRequestID == requestID {
                    self.captureTask = nil
                    self.activeRequestID = nil
                }
            }
            do {
                let frame = try await self.captureService.captureMouseDisplay()
                guard self.activeRequestID == requestID else { return }
                self.deadlineTask?.cancel()
                self.deadlineTask = nil
                guard self.capture.recordCapturedFrame(for: requestID) else { return }
                self.presentFrozenFrame(frame)
            } catch {
                guard self.activeRequestID == requestID else { return }
                self.deadlineTask?.cancel()
                self.deadlineTask = nil
                guard self.capture.recordFailure(for: requestID) else { return }
                if let failure = error as? CaptureFailure, failure == .cancelled {
                    return
                }
                self.presentError(error)
            }
        }
    }

    func cancelCapture() {
        captureTask?.cancel()
        deadlineTask?.cancel()
        captureTask = nil
        deadlineTask = nil
        activeRequestID = nil
        capture.finishCaptureRequest()
    }

    private func presentFrozenFrame(_ frame: CapturedFrame) {
        presentingFeedback = true
        defer {
            presentingFeedback = false
            capture.finishCaptureRequest()
        }

        // P0-05 will display the frozen CGImage inside a real selection NSPanel.
        // Until then, report metadata without writing or uploading the image.
        let alert = NSAlert()
        alert.messageText = "已捕获冻结图像"
        alert.informativeText = "显示器 ID：\(frame.geometry.displayID)\n" +
            "源图尺寸：\(frame.image.width) × \(frame.image.height) 像素\n" +
            "原生选区将在 P0-05 接入。"
        NSApp.activate(ignoringOtherApps: true)
        _ = alert.runModal()
    }

    private func presentError(_ error: Error) {
        presentingFeedback = true
        defer { presentingFeedback = false }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "截图未完成"
        alert.informativeText = error.localizedDescription
        NSApp.activate(ignoringOtherApps: true)
        _ = alert.runModal()
    }
}
