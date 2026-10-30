// P0-07 macOS CI: verify a visible window owned by this process does not
// contaminate PicPaste CaptureService screenshots. Never save or print pixels.
import AppKit
import CoreGraphics
import Darwin
import Foundation
import ScreenCaptureKit

private enum CaptureWindowTestFailure: Error {
    case notAuthorized
    case noDisplay
    case invisibleTestWindow
    case controlScreenshotMissingWindow
    case screenshotContainsOwnWindow
    case invalidGeometry
    case unexpectedAuthorizationCallbackCount
    case preCancelledCaptureSucceeded
    case unexpectedCancellationResult
    case cancelledStressAttemptSucceeded
    case cancelledStressAttemptDidNotNormalize
    case coordinatorRecoveryFailed
    case memorySampleUnavailable
    case memoryGrowthExceeded
}

private struct RGB {
    let red: UInt8
    let green: UInt8
    let blue: UInt8

    var isMagentaMarker: Bool {
        red >= 180 && green <= 90 && blue >= 180
    }
}

@main
struct CaptureOwnWindowProbe {
    @MainActor
    static func main() async {
        do {
            try await verify()
            print("CI_OWN_WINDOW_REPEAT_RESULT=PASS")
            exit(0)
        } catch {
            print("CI_OWN_WINDOW_REPEAT_ERROR=\(String(reflecting: type(of: error)))")
            print("CI_OWN_WINDOW_REPEAT_RESULT=FAIL")
            exit(1)
        }
    }

    @MainActor
    private static func verify() async throws {
        guard CGPreflightScreenCaptureAccess() else { throw CaptureWindowTestFailure.notAuthorized }
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        let pointer = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(pointer) }),
              let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        else { throw CaptureWindowTestFailure.noDisplay }

        let displayID = CGDirectDisplayID(number.uint32Value)
        let frame = screen.frame
        let windowFrame = CGRect(
            x: frame.midX - 100, y: frame.midY - 80,
            width: 200, height: 160
        )
        let window = NSWindow(
            contentRect: windowFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = .floating
        window.isOpaque = true
        window.backgroundColor = .magenta
        window.hasShadow = false
        let content = NSView(frame: CGRect(origin: .zero, size: windowFrame.size))
        content.wantsLayer = true
        content.layer?.backgroundColor = NSColor.magenta.cgColor
        window.contentView = content
        defer {
            window.orderOut(nil)
            window.close()
        }
        window.makeKeyAndOrderFront(nil)
        RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        guard window.isVisible else { throw CaptureWindowTestFailure.invisibleTestWindow }

        // A request cancelled before its first suspension must produce the
        // public CaptureFailure.cancelled rather than a raw CancellationError.
        // This is an actual CaptureService failure, followed by real capture retry.
        var cancelledAuthorizationCallbacks = 0
        let cancelledTask = Task { @MainActor () throws -> CapturedFrame in
            withUnsafeCurrentTask { $0?.cancel() }
            return try await CaptureService().captureMouseDisplay {
                cancelledAuthorizationCallbacks += 1
            }
        }
        do {
            _ = try await cancelledTask.value
            throw CaptureWindowTestFailure.preCancelledCaptureSucceeded
        } catch let failure as CaptureFailure {
            guard failure == .cancelled else {
                throw CaptureWindowTestFailure.unexpectedCancellationResult
            }
        } catch {
            throw CaptureWindowTestFailure.unexpectedCancellationResult
        }
        guard cancelledAuthorizationCallbacks == 0 else {
            throw CaptureWindowTestFailure.unexpectedAuthorizationCallbackCount
        }
        print("CI_PRE_CANCELLED_CAPTURE=PASS")

        // Positive control: verify the unfiltered ScreenCaptureKit frame
        // contains our synthetic magenta window. Otherwise "excluded" would
        // be an unproven claim on this runner.
        let available = try await SCShareableContent.excludingDesktopWindows(
            false, onScreenWindowsOnly: true
        )
        guard let display = available.displays.first(where: { $0.displayID == displayID })
        else { throw CaptureWindowTestFailure.noDisplay }
        let configuration = SCStreamConfiguration()
        configuration.width = display.width
        configuration.height = display.height
        configuration.showsCursor = false
        let unfiltered = try await SCScreenshotManager.captureImage(
            contentFilter: SCContentFilter(display: display, excludingWindows: []),
            configuration: configuration
        )
        let center = CGPoint(x: windowFrame.midX, y: windowFrame.midY)
        guard try pixelColor(in: unfiltered, at: center, screenFrame: frame).isMagentaMarker else {
            throw CaptureWindowTestFailure.controlScreenshotMissingWindow
        }
        print("CI_OWN_WINDOW_POSITIVE_CONTROL=PASS")

        // The production service must find/exclude this process' visible
        // window while the same real overlay is on screen.
        let service = CaptureService()
        let coordinator = CaptureCoordinator()
        var successfulCaptures = 0
        var cancelledRecoveries = 0
        var warmedRSSKiB: Int?
        var peakRSSKiB = 0

        for iteration in 0..<30 {
            // Every tenth iteration starts with an intentionally cancelled
            // *real CaptureService request*. The public error and the
            // coordinator must recover before the next actual screenshot.
            if iteration % 10 == 9 {
                guard coordinator.beginCaptureRequest() else {
                    throw CaptureWindowTestFailure.coordinatorRecoveryFailed
                }
                let failedID = coordinator.generation
                var ignoredAuthorizationCallbacks = 0
                let cancelledTask = Task { @MainActor () throws -> CapturedFrame in
                    withUnsafeCurrentTask { $0?.cancel() }
                    return try await service.captureMouseDisplay {
                        ignoredAuthorizationCallbacks += 1
                    }
                }
                do {
                    _ = try await cancelledTask.value
                    throw CaptureWindowTestFailure.cancelledStressAttemptSucceeded
                } catch let failure as CaptureFailure {
                    guard failure == .cancelled else {
                        throw CaptureWindowTestFailure.cancelledStressAttemptDidNotNormalize
                    }
                } catch {
                    throw CaptureWindowTestFailure.cancelledStressAttemptDidNotNormalize
                }
                guard ignoredAuthorizationCallbacks == 0,
                      coordinator.recordFailure(for: failedID),
                      coordinator.phase == .idle else {
                    throw CaptureWindowTestFailure.coordinatorRecoveryFailed
                }
                cancelledRecoveries += 1
            }

            guard coordinator.beginCaptureRequest() else {
                throw CaptureWindowTestFailure.coordinatorRecoveryFailed
            }
            let requestID = coordinator.generation
            var callbackCount = 0
            let captured = try await service.captureMouseDisplay {
                callbackCount += 1
            }
            guard callbackCount == 1 else {
                throw CaptureWindowTestFailure.unexpectedAuthorizationCallbackCount
            }
            guard captured.geometry.displayID == displayID,
                  captured.geometry.desktopFramePoints == frame,
                  captured.image.width == captured.geometry.imageWidthPixels,
                  captured.image.height == captured.geometry.imageHeightPixels,
                  captured.image.width > 0, captured.image.height > 0 else {
                throw CaptureWindowTestFailure.invalidGeometry
            }
            guard !(try pixelColor(
                in: captured.image, at: center, screenFrame: frame
            )).isMagentaMarker else {
                throw CaptureWindowTestFailure.screenshotContainsOwnWindow
            }
            guard coordinator.recordCapturedFrame(for: requestID),
                  coordinator.phase == .showingFrozenFrame else {
                throw CaptureWindowTestFailure.coordinatorRecoveryFailed
            }
            coordinator.finishCaptureRequest()
            guard coordinator.phase == .idle else {
                throw CaptureWindowTestFailure.coordinatorRecoveryFailed
            }
            successfulCaptures += 1
            // Do not retain any CGImage samples across the loop.
            if iteration == 0 { print("CI_OWN_WINDOW_EXCLUSION=PASS") }

            if iteration == 2 {
                warmedRSSKiB = try residentRSSKiB()
                peakRSSKiB = warmedRSSKiB!
            }
            if iteration >= 3 && (iteration % 5 == 4 || iteration == 29) {
                peakRSSKiB = max(peakRSSKiB, try residentRSSKiB())
            }
        }

        guard successfulCaptures == 30, cancelledRecoveries == 3,
              let baseline = warmedRSSKiB else {
            throw CaptureWindowTestFailure.coordinatorRecoveryFailed
        }
        let growthKiB = max(0, peakRSSKiB - baseline)
        // A CI smoke bound, not a claim of leak-free long-running operation.
        let maximumGrowthKiB = 256 * 1024
        print("CI_REPEATED_REAL_CAPTURES=\(successfulCaptures)")
        print("CI_REPEATED_REAL_CAPTURE_RECOVERIES=\(cancelledRecoveries)")
        print("CI_CAPTURE_RSS_BASELINE_KIB=\(baseline)")
        print("CI_CAPTURE_RSS_PEAK_GROWTH_KIB=\(growthKiB)")
        print("CI_CAPTURE_RSS_GROWTH_LIMIT_KIB=\(maximumGrowthKiB)")
        guard growthKiB <= maximumGrowthKiB else {
            throw CaptureWindowTestFailure.memoryGrowthExceeded
        }
        print("CI_CAPTURE_RSS_BOUND_RESULT=PASS")
        print("CI_REPEATED_REAL_CAPTURES_RESULT=PASS")
    }

    private static func residentRSSKiB() throws -> Int {
        // Resident set from the current test process, no elevated privileges.
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-o", "rss=", "-p", String(getpid())]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()
        try process.run()
        let bytes = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0,
              let text = String(data: bytes, encoding: .utf8),
              let value = Int(text.trimmingCharacters(in: .whitespacesAndNewlines)),
              value > 0 else {
            throw CaptureWindowTestFailure.memorySampleUnavailable
        }
        return value
    }

    private static func pixelColor(
        in image: CGImage, at point: CGPoint, screenFrame: CGRect
    ) throws -> RGB {
        let x = min(image.width - 1, max(0, Int(
            (point.x - screenFrame.minX) * CGFloat(image.width) / screenFrame.width
        )))
        let y = min(image.height - 1, max(0, Int(
            (screenFrame.maxY - point.y) * CGFloat(image.height) / screenFrame.height
        )))
        guard let cropped = image.cropping(to: CGRect(x: x, y: y, width: 1, height: 1)),
              let context = CGContext(
                data: nil, width: 1, height: 1,
                bitsPerComponent: 8, bytesPerRow: 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                    | CGBitmapInfo.byteOrder32Big.rawValue
              ) else { throw CaptureWindowTestFailure.invalidGeometry }
        context.draw(cropped, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        guard let bytes = context.data?.assumingMemoryBound(to: UInt8.self) else {
            throw CaptureWindowTestFailure.invalidGeometry
        }
        return RGB(red: bytes[0], green: bytes[1], blue: bytes[2])
    }
}
