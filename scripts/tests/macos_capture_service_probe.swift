// Compile together with PicPaste's actual CaptureService, CapturedFrame,
// and ScreenPermissionService sources. Never save or upload screen pixels.
import AppKit
import CoreGraphics
import Foundation
import Darwin

@main
struct CaptureServiceCIProbe {
    @MainActor
    static func main() async {
        print("CI_APP_CAPTURE_SERVICE_BEGIN")
        guard CGPreflightScreenCaptureAccess() else {
            print("CI_APP_CAPTURE_SERVICE_RESULT=NOT_PREAUTHORIZED")
            exit(3)
        }

        _ = NSApplication.shared
        let pointer = NSEvent.mouseLocation
        guard NSScreen.screens.contains(where: { $0.frame.contains(pointer) }) else {
            print("CI_APP_CAPTURE_SERVICE_RESULT=NO_DISPLAY_AT_POINTER")
            exit(4)
        }

        var permissionCompletionCount = 0
        do {
            let capture = try await CaptureService().captureMouseDisplay {
                permissionCompletionCount += 1
            }

            guard permissionCompletionCount == 1,
                  capture.image.width > 0,
                  capture.image.height > 0,
                  capture.image.width == capture.geometry.imageWidthPixels,
                  capture.image.height == capture.geometry.imageHeightPixels else {
                print("CI_APP_CAPTURE_SERVICE_RESULT=INVALID_CAPTURE")
                exit(5)
            }

            print("CI_APP_CAPTURE_SERVICE_DISPLAY_ID=\(capture.geometry.displayID)")
            print("CI_APP_CAPTURE_SERVICE_IMAGE_SIZE=\(capture.image.width)x\(capture.image.height)")
            print("CI_APP_CAPTURE_SERVICE_RESULT=PASS")
            exit(0)
        } catch {
            print("CI_APP_CAPTURE_SERVICE_ERROR_TYPE=\(String(reflecting: type(of: error)))")
            if let failure = error as? CaptureFailure {
                print("CI_APP_CAPTURE_SERVICE_FAILURE=\(String(describing: failure))")
            }
            print("CI_APP_CAPTURE_SERVICE_RESULT=FAILED")
            exit(1)
        }
    }
}
