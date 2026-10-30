import AppKit
import CoreGraphics
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
}
