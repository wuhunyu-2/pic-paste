import XCTest
@testable import PicPaste

@MainActor
final class HotkeyStateTests: XCTestCase {
    func testRegistrationDispatchesCaptureAction() throws {
        let backend = FakeHotkeyBackend()
        let manager = GlobalHotkeyManager(backend: backend)
        var requests = 0

        try manager.register(AppSettings.defaultCaptureHotkey) { requests += 1 }

        XCTAssertEqual(manager.registeredShortcut, AppSettings.defaultCaptureHotkey)
        XCTAssertEqual(backend.registrations.count, 1)
        backend.fireFirstHotkey()
        XCTAssertEqual(requests, 1)
    }

    func testConflictPreservesAlreadyWorkingHotkey() throws {
        let backend = FakeHotkeyBackend()
        let manager = GlobalHotkeyManager(backend: backend)
        let first = AppSettings.defaultCaptureHotkey
        let replacement = HotkeyShortcut(keyCode: 22, modifiers: 3)
        var calls = 0

        try manager.register(first) { calls += 1 }
        backend.failNextRegistration = true

        XCTAssertThrowsError(try manager.register(replacement) { calls += 10 })
        XCTAssertEqual(manager.registeredShortcut, first)
        XCTAssertEqual(backend.registrations.count, 1)
        XCTAssertEqual(backend.removed.count, 0)

        backend.fireFirstHotkey()
        XCTAssertEqual(calls, 1)
    }

    func testSuccessfulReplacementUnregistersOldHotkey() throws {
        let backend = FakeHotkeyBackend()
        let manager = GlobalHotkeyManager(backend: backend)
        let first = AppSettings.defaultCaptureHotkey
        let replacement = HotkeyShortcut(keyCode: 22, modifiers: 3)

        try manager.register(first) {}
        let oldID = try XCTUnwrap(backend.registrations.keys.first)
        try manager.register(replacement) {}

        XCTAssertEqual(manager.registeredShortcut, replacement)
        XCTAssertEqual(backend.registrations.count, 1)
        XCTAssertNil(backend.registrations[oldID])
        XCTAssertEqual(backend.removed, [oldID])
    }

    func testDuplicateBindingDoesNotRegisterAgain() throws {
        let backend = FakeHotkeyBackend()
        let manager = GlobalHotkeyManager(backend: backend)

        try manager.register(AppSettings.defaultCaptureHotkey) {}
        try manager.register(AppSettings.defaultCaptureHotkey) {}

        XCTAssertEqual(backend.registrations.count, 1)
        XCTAssertEqual(backend.totalRegistrations, 1)
    }

    func testShutdownUnregistersAndReleasesBackend() throws {
        let backend = FakeHotkeyBackend()
        let manager = GlobalHotkeyManager(backend: backend)

        try manager.register(AppSettings.defaultCaptureHotkey) {}
        manager.invalidate()

        XCTAssertNil(manager.registeredShortcut)
        XCTAssertTrue(backend.registrations.isEmpty)
        XCTAssertTrue(backend.wasShutdown)
    }

    func testCaptureRequestsDoNotStartOverlappingSessions() {
        let coordinator = CaptureCoordinator()

        XCTAssertTrue(coordinator.beginCaptureRequest())
        XCTAssertFalse(coordinator.beginCaptureRequest())
        coordinator.finishCaptureRequest()
        XCTAssertTrue(coordinator.beginCaptureRequest())
        coordinator.finishCaptureRequest()
        XCTAssertEqual(coordinator.phase, .idle)
    }
}

@MainActor
private final class FakeHotkeyBackend: HotkeyBackend {
    var registrations: [UInt32: (@MainActor () -> Void)] = [:]
    var removed: [UInt32] = []
    var totalRegistrations = 0
    var failNextRegistration = false
    var wasShutdown = false

    func register(_ shortcut: HotkeyShortcut, onTrigger: @escaping @MainActor () -> Void) throws -> UInt32 {
        if failNextRegistration {
            failNextRegistration = false
            throw NSError(domain: "HotkeyConflict", code: 1)
        }
        totalRegistrations += 1
        let token = UInt32(totalRegistrations)
        registrations[token] = onTrigger
        return token
    }

    func unregister(_ token: UInt32) {
        registrations.removeValue(forKey: token)
        removed.append(token)
    }

    func shutdown() {
        registrations.removeAll()
        wasShutdown = true
    }

    func fireFirstHotkey() {
        guard let token = registrations.keys.sorted().first else { return }
        registrations[token]?()
    }
}
