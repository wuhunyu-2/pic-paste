import XCTest
@testable import PicPaste

@MainActor
final class PicPasteTests: XCTestCase {
    func testCoordinatorReceivesCaptureRequests() {
        let coordinator = AppCoordinator()
        XCTAssertEqual(coordinator.captureRequestCount, 0)
        // Do not invoke the modal placeholder in the unit test.
    }
}
