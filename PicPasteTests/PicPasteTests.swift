import AppKit
import CoreGraphics
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

}
