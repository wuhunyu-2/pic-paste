import AppKit
import CoreGraphics
import ImageIO
import ScreenCaptureKit
import XCTest
@testable import PicPaste

@MainActor
final class PicPasteTests: XCTestCase {
    func testCoordinatorReceivesCaptureRequests() {
        let coordinator = AppCoordinator()
        XCTAssertEqual(coordinator.captureRequestCount, 0)
        // Do not invoke the modal placeholder in the unit test.
    }

    func testMenuBarSupportsExplicitMainActorCleanup() {
        let menuBar = MenuBarController(coordinator: AppCoordinator())
        menuBar.invalidate()
    }

    // Uses an actual AppKit window with a synthetic frame. ScreenCaptureKit
    // permissions and physical keyboard/mouse behavior are tested separately.
    private func makeSelectionFixture() throws -> CapturedFrame {
        let context = try XCTUnwrap(CGContext(
            data: nil, width: 16, height: 16, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        let image = try XCTUnwrap(context.makeImage())
        let geometry = DisplayGeometry(
            displayID: 1,
            desktopFramePoints: CGRect(x: 40, y: 40, width: 160, height: 100),
            imageWidthPixels: 16, imageHeightPixels: 16
        )
        return CapturedFrame(geometry: geometry, image: image)
    }

    private func visibleSelectionPanels() -> [NSPanel] {
        NSApp.windows.compactMap { $0 as? NSPanel }
            .filter { $0.isVisible && $0.contentView is SelectionView }
    }

    func testSelectionOverlayIsVisibleAndDismissesWithoutCallback() throws {
        let controller = SelectionPanelController()
        defer { controller.dismiss() }
        var completionCount = 0
        controller.present(frame: try makeSelectionFixture()) { _ in completionCount += 1 }

        let panel = try XCTUnwrap(visibleSelectionPanels().first)
        XCTAssertTrue(panel.isVisible)
        XCTAssertEqual(panel.level, .screenSaver)

        controller.dismiss()
        XCTAssertFalse(panel.isVisible)
        XCTAssertEqual(visibleSelectionPanels().count, 0)
        XCTAssertEqual(completionCount, 0)
    }

    func testSelectionOverlayCancelsOnlyOnceAndReopeningReplacesOldWindow() throws {
        let controller = SelectionPanelController()
        defer { controller.dismiss() }
        var completions: [PixelRect?] = []
        let frame = try makeSelectionFixture()
        controller.present(frame: frame) { completions.append($0) }
        let firstPanel = try XCTUnwrap(visibleSelectionPanels().first)

        controller.present(frame: frame) { completions.append($0) }
        XCTAssertFalse(firstPanel.isVisible)
        XCTAssertEqual(visibleSelectionPanels().count, 1)

        let secondPanel = try XCTUnwrap(visibleSelectionPanels().first)
        let selection = try XCTUnwrap(secondPanel.contentView as? SelectionView)
        selection.cancel()
        selection.cancel()

        XCTAssertEqual(completions.count, 1)
        XCTAssertNil(completions[0])
        XCTAssertFalse(secondPanel.isVisible)
        XCTAssertEqual(visibleSelectionPanels().count, 0)
    }
    func testThirtySelectionSessionsReturnToIdleWithoutStaleOverlay() throws {
        let coordinator = CaptureCoordinator()
        let controller = SelectionPanelController()
        defer { controller.dismiss() }
        let fixture = try makeSelectionFixture()
        var completionCount = 0

        for index in 0..<30 {
            XCTAssertTrue(coordinator.beginCaptureRequest(), "Iteration \(index): next capture should begin")
            let request = coordinator.generation
            XCTAssertTrue(coordinator.recordCapturedFrame(for: request))
            XCTAssertFalse(coordinator.beginCaptureRequest(), "Iteration \(index): overlapping capture rejected")

            controller.present(frame: fixture) { result in
                XCTAssertNil(result)
                completionCount += 1
                coordinator.finishCaptureRequest()
            }

            let panel = try XCTUnwrap(visibleSelectionPanels().first)
            XCTAssertEqual(visibleSelectionPanels().count, 1)
            let view = try XCTUnwrap(panel.contentView as? SelectionView)
            view.cancel()
            view.cancel() // A second cancellation must not invoke completion twice.

            XCTAssertFalse(panel.isVisible, "Iteration \(index): old panel still visible")
            XCTAssertTrue(visibleSelectionPanels().isEmpty, "Iteration \(index): transparent overlay remains")
            XCTAssertEqual(coordinator.phase, .idle)
            XCTAssertEqual(completionCount, index + 1)
        }
    }

    func testSyntheticEscapeKeyClosesRealSelectionPanelOnce() throws {
        let controller = SelectionPanelController()
        defer { controller.dismiss() }
        var completionCount = 0
        controller.present(frame: try makeSelectionFixture()) { selection in
            XCTAssertNil(selection)
            completionCount += 1
        }
        let panel = try XCTUnwrap(visibleSelectionPanels().first)
        let view = try XCTUnwrap(panel.contentView as? SelectionView)
        let escape = try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: panel.windowNumber, context: nil,
            characters: "\u{1B}", charactersIgnoringModifiers: "\u{1B}",
            isARepeat: false, keyCode: 53
        ))

        view.keyDown(with: escape)
        view.cancel() // Validate idempotent completion after Escape.

        XCTAssertEqual(completionCount, 1)
        XCTAssertFalse(panel.isVisible)
        XCTAssertTrue(visibleSelectionPanels().isEmpty)
    }

    func testRealCaptureServiceOnAuthorizedDesktop() async throws {
        // The XCTest host has its own TCC identity. Do not trigger a permission
        // prompt in unattended CI; explicitly report an untested environment.
        guard CGPreflightScreenCaptureAccess() else {
            throw XCTSkip("XCTest host lacks preauthorized Screen Recording permission")
        }
        guard NSScreen.screens.contains(where: { $0.frame.contains(NSEvent.mouseLocation) }) else {
            throw XCTSkip("Hosted macOS has no display under the mouse pointer")
        }

        var authorizationCompletionCount = 0
        let result = try await CaptureService().captureMouseDisplay {
            authorizationCompletionCount += 1
        }

        XCTAssertEqual(authorizationCompletionCount, 1)
        XCTAssertGreaterThan(result.image.width, 0)
        XCTAssertGreaterThan(result.image.height, 0)
        XCTAssertEqual(result.image.width, result.geometry.imageWidthPixels)
        XCTAssertEqual(result.image.height, result.geometry.imageHeightPixels)
        XCTAssertTrue(NSScreen.screens.contains(where: { $0.frame == result.geometry.desktopFramePoints }))
        print("CI_CAPTURE_SERVICE_RESULT=PASS image=\(result.image.width)x\(result.image.height)")
    }


    // These events go through SelectionView's real NSResponder overrides and
    // its owning NSPanel. No CGEvent posts, real mouse or TCC are implied.
    private func sendMouse(
        _ type: NSEvent.EventType, at point: CGPoint,
        to view: SelectionView, in panel: NSPanel
    ) throws {
        let event = try XCTUnwrap(NSEvent.mouseEvent(
            with: type, location: point, modifierFlags: [], timestamp: 0,
            windowNumber: panel.windowNumber, context: nil,
            eventNumber: 1, clickCount: 1, pressure: 1
        ))
        switch type {
        case .leftMouseDown: view.mouseDown(with: event)
        case .leftMouseDragged: view.mouseDragged(with: event)
        case .leftMouseUp: view.mouseUp(with: event)
        default: XCTFail("Unsupported synthetic mouse event")
        }
    }

    private func drag(
        from start: CGPoint, to end: CGPoint,
        on view: SelectionView, panel: NSPanel
    ) throws {
        try sendMouse(.leftMouseDown, at: start, to: view, in: panel)
        try sendMouse(.leftMouseDragged, at: end, to: view, in: panel)
        try sendMouse(.leftMouseUp, at: end, to: view, in: panel)
    }

    private func confirmWithEnter(on view: SelectionView, panel: NSPanel) throws {
        let enter = try XCTUnwrap(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
            windowNumber: panel.windowNumber, context: nil,
            characters: "\r", charactersIgnoringModifiers: "\r",
            isARepeat: false, keyCode: 36
        ))
        view.keyDown(with: enter)
    }

    func testMouseDragEnterProducesExpectedCropPNGAndPasteboardData() throws {
        let controller = SelectionPanelController()
        defer { controller.dismiss() }
        let frozen = try makeSelectionFixture()
        var results: [PixelRect?] = []
        controller.present(frame: frozen) { results.append($0) }
        let panel = try XCTUnwrap(visibleSelectionPanels().first)
        let view = try XCTUnwrap(panel.contentView as? SelectionView)

        // View-local y-up points (160x100), original CGImage is 16x16 pixels.
        try drag(from: CGPoint(x: 20, y: 20), to: CGPoint(x: 100, y: 70),
                 on: view, panel: panel)
        try confirmWithEnter(on: view, panel: panel)
        try confirmWithEnter(on: view, panel: panel) // no duplicate callback

        XCTAssertEqual(results.count, 1)
        let crop = try XCTUnwrap(results[0])
        XCTAssertEqual(crop, PixelRect(x: 2, y: 4, width: 8, height: 9))
        XCTAssertFalse(panel.isVisible)
        XCTAssertTrue(visibleSelectionPanels().isEmpty)

        let composed = try ImageComposer.compose(source: frozen.image, crop: crop, radius: 0)
        let png = try PNGExporter.encode(composed)
        let src = try XCTUnwrap(CGImageSourceCreateWithData(png as CFData, nil))
        let output = try XCTUnwrap(CGImageSourceCreateImageAtIndex(src, 0, nil))
        XCTAssertEqual(output.width, 8)
        XCTAssertEqual(output.height, 9)

        let pasteboard = NSPasteboard(name: NSPasteboard.Name("PicPaste-Mouse-CI-\(UUID().uuidString)"))
        XCTAssertTrue(ClipboardWriter.copyPNG(png, to: pasteboard))
        XCTAssertEqual(pasteboard.data(forType: .png), png)
    }

    func testMouseMoveThenEnterClampsCoordinatesOnRealOverlay() throws {
        let controller = SelectionPanelController()
        defer { controller.dismiss() }
        var result: PixelRect?
        controller.present(frame: try makeSelectionFixture()) { result = $0 }
        let panel = try XCTUnwrap(visibleSelectionPanels().first)
        let view = try XCTUnwrap(panel.contentView as? SelectionView)

        try drag(from: CGPoint(x: 20, y: 20), to: CGPoint(x: 100, y: 70),
                 on: view, panel: panel)
        try drag(from: CGPoint(x: 50, y: 45), to: CGPoint(x: 70, y: 55),
                 on: view, panel: panel)
        try confirmWithEnter(on: view, panel: panel)

        XCTAssertEqual(result, PixelRect(x: 4, y: 3, width: 8, height: 9))
        XCTAssertTrue(visibleSelectionPanels().isEmpty)
    }

    func testAllEightMouseHandlesMapToExactSourcePixelCrops() throws {
        struct Scenario {
            let name: String
            let grab: CGPoint
            let target: CGPoint
            let expected: PixelRect
        }
        let scenarios = [
            Scenario(name: "top-left", grab: CGPoint(x: 20, y: 80),
                     target: CGPoint(x: 10, y: 90), expected: PixelRect(x: 1, y: 1, width: 11, height: 12)),
            Scenario(name: "top", grab: CGPoint(x: 70, y: 80),
                     target: CGPoint(x: 70, y: 90), expected: PixelRect(x: 2, y: 1, width: 10, height: 12)),
            Scenario(name: "top-right", grab: CGPoint(x: 120, y: 80),
                     target: CGPoint(x: 130, y: 90), expected: PixelRect(x: 2, y: 1, width: 11, height: 12)),
            Scenario(name: "right", grab: CGPoint(x: 120, y: 50),
                     target: CGPoint(x: 130, y: 50), expected: PixelRect(x: 2, y: 3, width: 11, height: 10)),
            Scenario(name: "bottom-right", grab: CGPoint(x: 120, y: 20),
                     target: CGPoint(x: 130, y: 10), expected: PixelRect(x: 2, y: 3, width: 11, height: 12)),
            Scenario(name: "bottom", grab: CGPoint(x: 70, y: 20),
                     target: CGPoint(x: 70, y: 10), expected: PixelRect(x: 2, y: 3, width: 10, height: 12)),
            Scenario(name: "bottom-left", grab: CGPoint(x: 20, y: 20),
                     target: CGPoint(x: 10, y: 10), expected: PixelRect(x: 1, y: 3, width: 11, height: 12)),
            Scenario(name: "left", grab: CGPoint(x: 20, y: 50),
                     target: CGPoint(x: 10, y: 50), expected: PixelRect(x: 1, y: 3, width: 11, height: 10))
        ]

        let controller = SelectionPanelController()
        defer { controller.dismiss() }
        let frozen = try makeSelectionFixture()
        for scenario in scenarios {
            var results: [PixelRect?] = []
            controller.present(frame: frozen) { results.append($0) }
            let panel = try XCTUnwrap(visibleSelectionPanels().first)
            let view = try XCTUnwrap(panel.contentView as? SelectionView)
            try drag(from: CGPoint(x: 20, y: 20), to: CGPoint(x: 120, y: 80),
                     on: view, panel: panel)
            try drag(from: scenario.grab, to: scenario.target, on: view, panel: panel)
            try confirmWithEnter(on: view, panel: panel)

            XCTAssertEqual(results.count, 1, scenario.name)
            XCTAssertEqual(results.first ?? nil, scenario.expected, scenario.name)
            XCTAssertTrue(visibleSelectionPanels().isEmpty, scenario.name)
        }
    }

}
