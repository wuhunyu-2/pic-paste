import UniformTypeIdentifiers
import AppKit

@MainActor
final class AppCoordinator {
    private let capture = CaptureCoordinator()
    private let captureService = CaptureService()
    private let selectionPanel = SelectionPanelController()
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
                let frame = try await self.captureService.captureMouseDisplay {
                    self.armCaptureDeadline(for: requestID)
                }
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

    private func armCaptureDeadline(for requestID: UInt64) {
        guard activeRequestID == requestID else { return }
        // If the OS stalls, restore idle and reject any later callback.
        deadlineTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(10))
            } catch {
                return
            }
            guard let self, self.activeRequestID == requestID else { return }
            self.captureTask?.cancel()
            self.captureTask = nil
            self.deadlineTask = nil
            self.activeRequestID = nil
            if self.capture.recordFailure(for: requestID) {
                self.presentError(CaptureFailure.timedOut)
            }
        }
    }

    func cancelCapture() {
        selectionPanel.dismiss()
        captureTask?.cancel()
        deadlineTask?.cancel()
        captureTask = nil
        deadlineTask = nil
        activeRequestID = nil
        capture.finishCaptureRequest()
    }

    private func presentFrozenFrame(_ frame: CapturedFrame) {
        selectionPanel.present(frame: frame) { [weak self] result in
            guard let self else { return }
            self.capture.finishCaptureRequest()
            guard let result else { return }
            self.exportSelection(frame: frame, pixelRect: result)
        }
    }

    private func exportSelection(frame: CapturedFrame, pixelRect: PixelRect) {
        do {
            let composed = try ImageComposer.compose(source: frame.image, crop: pixelRect, radius: 0)
            let pngData = try PNGExporter.encode(composed)
            let alert = NSAlert()
            alert.messageText = "截图已准备好"
            alert.informativeText = "选择复制 PNG 到剪贴板或保存 PNG 文件。"
            alert.addButton(withTitle: "复制")
            alert.addButton(withTitle: "保存…")
            alert.addButton(withTitle: "取消")
            NSApp.activate(ignoringOtherApps: true)
            switch alert.runModal() {
            case .alertFirstButtonReturn:
                if !ClipboardWriter.copyPNG(pngData) {
                    presentError(PNGExportError.encodingFailed)
                }
            case .alertSecondButtonReturn:
                let savePanel = NSSavePanel()
                savePanel.allowedContentTypes = [.png]
                savePanel.nameFieldStringValue = "PicPaste.png"
                if savePanel.runModal() == .OK, let target = savePanel.url {
                    try PNGExporter.save(pngData, to: target)
                }
            default: break
            }
        } catch {
            presentError(error)
        }
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
