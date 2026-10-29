import AppKit
import CoreGraphics
import ScreenCaptureKit

/// One-shot capture only. This service does not create persistent SCStreams,
/// helper processes or selection overlays.
@MainActor
final class CaptureService {
    private let permissions = ScreenPermissionService()

    func captureMouseDisplay() async throws -> CapturedFrame {
        try permissions.ensureAuthorized()
        try Task.checkCancellation()

        do {
            let shareable = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )
            try Task.checkCancellation()

            // NSEvent.mouseLocation uses AppKit global logical points. Look up
            // the associated NSScreen/displayID rather than scaling a global
            // origin or mixing it with ScreenCaptureKit's display coordinates.
            let pointer = NSEvent.mouseLocation
            guard let screen = NSScreen.screens.first(where: { $0.frame.contains(pointer) }),
                  let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                throw CaptureFailure.noDisplayUnderPointer
            }
            let displayID = CGDirectDisplayID(number.uint32Value)
            let originalFrame = screen.frame
            guard let display = shareable.displays.first(where: { $0.displayID == displayID }) else {
                throw CaptureFailure.displayDisconnected
            }

            // Always exclude PicPaste's own windows from the source image, even
            // if Settings is open. The overlay is only created in P0-05, AFTER
            // this frozen capture has finished.
            let appID = Bundle.main.bundleIdentifier ?? NSRunningApplication.current.bundleIdentifier ?? ""
            let ownApps = shareable.applications.filter { $0.bundleIdentifier == appID }
            let ownWindows = shareable.windows.filter { $0.owningApplication?.bundleIdentifier == appID }

            let filter: SCContentFilter
            if !ownApps.isEmpty {
                filter = SCContentFilter(
                    display: display,
                    excludingApplications: ownApps,
                    exceptingWindows: []
                )
            } else {
                // Some hidden menu-bar apps may not be in the apps list.
                // Explicitly exclude any matching windows instead.
                if ownWindows.isEmpty && NSApp.windows.contains(where: { $0.isVisible }) {
                    throw CaptureFailure.cannotExcludeOwnWindows
                }
                filter = SCContentFilter(display: display, excludingWindows: ownWindows)
            }

            let configuration = SCStreamConfiguration()
            configuration.width = display.width
            configuration.height = display.height
            configuration.showsCursor = false

            let image = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: configuration
            )
            try Task.checkCancellation()

            guard let currentScreen = NSScreen.screens.first(where: {
                ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == displayID
            }), currentScreen.frame == originalFrame else {
                throw CaptureFailure.displayDisconnected
            }

            return CapturedFrame(
                geometry: DisplayGeometry(
                    displayID: displayID,
                    desktopFramePoints: originalFrame,
                    imageWidthPixels: image.width,
                    imageHeightPixels: image.height
                ),
                image: image
            )
        } catch is CancellationError {
            throw CaptureFailure.cancelled
        } catch let failure as CaptureFailure {
            throw failure
        } catch {
            if !CGPreflightScreenCaptureAccess() {
                throw CaptureFailure.permissionDenied
            }
            throw CaptureFailure.system(error.localizedDescription)
        }
    }
}
