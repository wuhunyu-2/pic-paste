// P0-07: One live ScreenCaptureKit frame through PicPaste's production classes,
// then native AppKit selection, PNG export and an isolated real NSPasteboard.
// This program does not save, print or upload any screenshot pixel data.
// It is NOT a physical-device/TCC-first-consent/keyboard-focus acceptance test.
import AppKit
import CoreGraphics
import Foundation
import ImageIO
import Darwin

private enum EndToEndFailure: Error {
    case screenRecordingNotAuthorized
    case pointerOutsideDisplays
    case invalidCapturedFrame
    case invalidCaptureState
    case selectionPanelNotVisible
    case syntheticEventCreationFailed
    case unexpectedSelection
    case panelWasNotCleanedUp
    case pngCouldNotBeDecoded
    case pngDimensionsMismatch
    case pasteboardRoundTripFailed
}

@main
struct LiveCaptureSelectionExportProbe {
    @MainActor
    static func main() async {
        do {
            try await verify()
            print("CI_PICPaste_E2E_RESULT=PASS")
            exit(0)
        } catch {
            // No captured pixels or potentially sensitive pixel summaries in logs.
            print("CI_PICPaste_E2E_ERROR=\(String(reflecting: type(of: error))):\(String(describing: error))")
            print("CI_PICPaste_E2E_RESULT=FAILED")
            exit(1)
        }
    }

    @MainActor
    private static func verify() async throws {
        // Unattended CI must not trigger an interactive TCC prompt.
        guard CGPreflightScreenCaptureAccess() else {
            throw EndToEndFailure.screenRecordingNotAuthorized
        }

        _ = NSApplication.shared
        guard NSScreen.screens.contains(where: { $0.frame.contains(NSEvent.mouseLocation) }) else {
            throw EndToEndFailure.pointerOutsideDisplays
        }

        let coordinator = CaptureCoordinator()
        guard coordinator.beginCaptureRequest() else { throw EndToEndFailure.invalidCaptureState }
        let requestID = coordinator.generation
        var authorizedCount = 0
        let frozen = try await CaptureService().captureMouseDisplay {
            authorizedCount += 1
        }
        guard authorizedCount == 1,
              frozen.image.width == frozen.geometry.imageWidthPixels,
              frozen.image.height == frozen.geometry.imageHeightPixels,
              coordinator.recordCapturedFrame(for: requestID) else {
            throw EndToEndFailure.invalidCapturedFrame
        }
        print("CI_PICPaste_E2E_CAPTURE=PASS")

        let panelController = SelectionPanelController()
        defer { panelController.dismiss() }

        var selectionCount = 0
        var selected: PixelRect?
        panelController.present(frame: frozen) { result in
            selected = result
            selectionCount += 1
            coordinator.finishCaptureRequest()
        }

        let visiblePanels = NSApp.windows.compactMap { $0 as? NSPanel }
            .filter { $0.isVisible && $0.contentView is SelectionView }
        guard visiblePanels.count == 1,
              let panel = visiblePanels.first,
              let view = panel.contentView as? SelectionView else {
            throw EndToEndFailure.selectionPanelNotVisible
        }

        // Use a central crop, away from window edges/handles, with no real
        // mouse input or OS-wide event posting. The real SelectionView methods
        // receive these synthetic NSEvents in their owning NSPanel.
        let size = view.bounds.size
        guard size.width > 100, size.height > 100 else {
            throw EndToEndFailure.invalidCapturedFrame
        }
        let from = CGPoint(x: size.width * 0.25, y: size.height * 0.25)
        let to = CGPoint(x: size.width * 0.75, y: size.height * 0.75)

        try sendMouse(.leftMouseDown, at: from, to: view, in: panel)
        try sendMouse(.leftMouseDragged, at: to, to: view, in: panel)
        try sendMouse(.leftMouseUp, at: to, to: view, in: panel)

        guard let enter = NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: panel.windowNumber, context: nil,
            characters: "\r", charactersIgnoringModifiers: "\r",
            isARepeat: false, keyCode: 36
        ) else {
            throw EndToEndFailure.syntheticEventCreationFailed
        }
        view.keyDown(with: enter)

        // Independent quarter-screen crop oracle: source CGImage uses y-down.
        let scaleX = CGFloat(frozen.image.width) / size.width
        let scaleY = CGFloat(frozen.image.height) / size.height
        let x0 = Int(floor(from.x * scaleX))
        let x1 = Int(ceil(to.x * scaleX))
        let y0 = Int(floor((size.height - to.y) * scaleY))
        let y1 = Int(ceil((size.height - from.y) * scaleY))
        let expected = PixelRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)

        guard selectionCount == 1, selected == expected,
              coordinator.phase == .idle,
              !panel.isVisible,
              NSApp.windows.filter({ $0.isVisible && $0.contentView is SelectionView }).isEmpty else {
            throw EndToEndFailure.unexpectedSelection
        }
        print("CI_PICPaste_E2E_SELECTION=PASS")

        let composed = try ImageComposer.compose(source: frozen.image, crop: expected, radius: 0)
        guard composed.width == expected.width, composed.height == expected.height else {
            throw EndToEndFailure.pngDimensionsMismatch
        }
        let png = try PNGExporter.encode(composed)
        guard let source = CGImageSourceCreateWithData(png as CFData, nil),
              let decoded = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw EndToEndFailure.pngCouldNotBeDecoded
        }
        guard decoded.width == expected.width, decoded.height == expected.height else {
            throw EndToEndFailure.pngDimensionsMismatch
        }
        print("CI_PICPaste_E2E_PNG=PASS")

        let pasteboard = NSPasteboard(
            name: NSPasteboard.Name("PicPaste-CI-E2E-\(UUID().uuidString)")
        )
        defer { pasteboard.clearContents() }
        guard ClipboardWriter.copyPNG(png, to: pasteboard),
              pasteboard.data(forType: .png) == png else {
            throw EndToEndFailure.pasteboardRoundTripFailed
        }
        print("CI_PICPaste_E2E_PASTEBOARD=PASS")
    }

    @MainActor
    private static func sendMouse(
        _ type: NSEvent.EventType, at point: CGPoint,
        to view: SelectionView, in panel: NSPanel
    ) throws {
        guard let event = NSEvent.mouseEvent(
            with: type, location: point, modifierFlags: [], timestamp: 0,
            windowNumber: panel.windowNumber, context: nil,
            eventNumber: 1, clickCount: 1, pressure: 1
        ) else {
            throw EndToEndFailure.syntheticEventCreationFailed
        }
        switch type {
        case .leftMouseDown: view.mouseDown(with: event)
        case .leftMouseDragged: view.mouseDragged(with: event)
        case .leftMouseUp: view.mouseUp(with: event)
        default: throw EndToEndFailure.syntheticEventCreationFailed
        }
    }
}
