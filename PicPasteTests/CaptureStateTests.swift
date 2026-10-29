import CoreGraphics
import XCTest
@testable import PicPaste

@MainActor
final class CaptureStateTests: XCTestCase {
    func testDuplicateCaptureIsRejected() {
        let coordinator = CaptureCoordinator()
        XCTAssertTrue(coordinator.beginCaptureRequest())
        XCTAssertFalse(coordinator.beginCaptureRequest())
        XCTAssertEqual(coordinator.phase, .capturing)
    }

    func testCancelInvalidatesLateSuccess() {
        let coordinator = CaptureCoordinator()
        XCTAssertTrue(coordinator.beginCaptureRequest())
        let requestID = coordinator.generation

        coordinator.finishCaptureRequest()

        XCTAssertFalse(coordinator.recordCapturedFrame(for: requestID))
        XCTAssertEqual(coordinator.phase, .idle)
        XCTAssertTrue(coordinator.beginCaptureRequest())
    }

    func testFailureRestoresIdleAndAllowsAnotherCapture() {
        let coordinator = CaptureCoordinator()
        XCTAssertTrue(coordinator.beginCaptureRequest())
        let requestID = coordinator.generation

        XCTAssertTrue(coordinator.recordFailure(for: requestID))
        XCTAssertEqual(coordinator.phase, .idle)
        XCTAssertTrue(coordinator.beginCaptureRequest())
    }

    func testStaleFailureCannotCancelNewRequest() {
        let coordinator = CaptureCoordinator()
        XCTAssertTrue(coordinator.beginCaptureRequest())
        let oldID = coordinator.generation
        coordinator.finishCaptureRequest()
        XCTAssertTrue(coordinator.beginCaptureRequest())
        let newID = coordinator.generation

        XCTAssertNotEqual(oldID, newID)
        XCTAssertFalse(coordinator.recordFailure(for: oldID))
        XCTAssertEqual(coordinator.phase, .capturing)
        XCTAssertTrue(coordinator.recordFailure(for: newID))
        XCTAssertEqual(coordinator.phase, .idle)
    }

    func testSuccessBlocksFurtherRequestsUntilDismissed() {
        let coordinator = CaptureCoordinator()
        XCTAssertTrue(coordinator.beginCaptureRequest())
        let requestID = coordinator.generation

        XCTAssertTrue(coordinator.recordCapturedFrame(for: requestID))
        XCTAssertEqual(coordinator.phase, .showingFrozenFrame)
        XCTAssertFalse(coordinator.beginCaptureRequest())
        coordinator.finishCaptureRequest()
        XCTAssertTrue(coordinator.beginCaptureRequest())
    }

    func testDisplayedGeometryDoesNotScaleGlobalNegativeCoordinates() {
        let frame = CGRect(x: -1920, y: 200, width: 1920, height: 1080)
        let geometry = DisplayGeometry(
            displayID: 42,
            desktopFramePoints: frame,
            imageWidthPixels: 3840,
            imageHeightPixels: 2160
        )
        XCTAssertEqual(geometry.displayID, 42)
        XCTAssertEqual(geometry.desktopFramePoints.minX, -1920)
        XCTAssertEqual(geometry.imageWidthPixels, 3840)
    }

    func testCancellationAndTimeoutHaveDistinctErrors() {
        XCTAssertNotEqual(CaptureFailure.cancelled, CaptureFailure.timedOut)
        XCTAssertNotEqual(CaptureFailure.permissionDenied, CaptureFailure.displayDisconnected)
    }
}
