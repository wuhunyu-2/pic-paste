// Hosted macOS CI capability probe. No screenshot pixels are printed or saved.
// Run after the AppKit desktop probe; a real physical desktop is NOT verified.
import AppKit
import CoreGraphics
import Foundation
import ScreenCaptureKit
import Darwin

print("CI_SCK_PROBE_BEGIN")
guard CGPreflightScreenCaptureAccess() else {
    print("CI_SCK_PROBE_RESULT=NOT_PREAUTHORIZED")
    exit(3)
}

Task { @MainActor in
    do {
        let available = try await SCShareableContent.excludingDesktopWindows(
            false, onScreenWindowsOnly: true
        )
        let mainID = CGMainDisplayID()
        guard let display = available.displays.first(where: { $0.displayID == mainID })
                ?? available.displays.first else {
            print("CI_SCK_PROBE_RESULT=NO_SHAREABLE_DISPLAY")
            exit(4)
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let configuration = SCStreamConfiguration()
        configuration.width = display.width
        configuration.height = display.height
        configuration.showsCursor = false

        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter, configuration: configuration
        )
        guard image.width > 0, image.height > 0,
              image.width == display.width, image.height == display.height else {
            print("CI_SCK_PROBE_RESULT=INVALID_IMAGE_DIMENSIONS")
            exit(5)
        }
        print("CI_SCK_DISPLAY_ID=\(display.displayID)")
        print("CI_SCK_IMAGE_SIZE=\(image.width)x\(image.height)")
        print("CI_SCK_PROBE_RESULT=PASS")
        exit(0)
    } catch {
        print("CI_SCK_PROBE_ERROR_TYPE=\(String(reflecting: type(of: error)))")
        print("CI_SCK_PROBE_RESULT=FAILED")
        exit(1)
    }
}
RunLoop.main.run()
