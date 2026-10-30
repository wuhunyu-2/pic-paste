import CoreGraphics
import XCTest
@testable import PicPaste

@MainActor
final class SelectionInteractionTests: XCTestCase {
    func testDragAndConfirm() {
        var state = SelectionInteraction()
        state.begin(at: CGPoint(x: 10, y: 20), bounds: CGRect(x: 0, y: 0, width: 100, height: 100))
        state.update(to: CGPoint(x: 50, y: 70))
        state.end()
        XCTAssertEqual(state.selection, CGRect(x: 10, y: 20, width: 40, height: 50))
        XCTAssertNotNil(state.confirm(display: DisplayGeometry(displayID: 1, desktopFramePoints: CGRect(x: 0, y: 0, width: 100, height: 100), imageWidthPixels: 200, imageHeightPixels: 200)))
    }

    func testMoveAndCancel() {
        var state = SelectionInteraction()
        state.begin(at: CGPoint(x: 10, y: 10), bounds: CGRect(x: 0, y: 0, width: 100, height: 100))
        state.update(to: CGPoint(x: 30, y: 30))
        state.end()
        state.begin(at: CGPoint(x: 20, y: 20), bounds: CGRect(x: 0, y: 0, width: 100, height: 100))
        state.update(to: CGPoint(x: 200, y: 200))
        state.end()
        XCTAssertEqual(state.selection, CGRect(x: 80, y: 80, width: 20, height: 20))
        state.cancel()
        XCTAssertNil(state.selection)
    }
}
