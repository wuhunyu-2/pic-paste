// Informational AppKit/WindowServer probe for a GitHub-hosted macOS runner.
// This does NOT validate ScreenCaptureKit TCC grants or a physical Mac display.
import AppKit
import ApplicationServices
import CoreGraphics
import Darwin
import Foundation

print("CI_DESKTOP_PROBE_BEGIN")
print("CI_DISPLAY_ID=\(CGMainDisplayID())")
print("CI_SCREEN_COUNT=\(NSScreen.screens.count)")
print("CI_SCREEN_CAPTURE_PREAUTHORIZED=\(CGPreflightScreenCaptureAccess())")
print("CI_ACCESSIBILITY_PREAUTHORIZED=\(AXIsProcessTrusted())")

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let window = NSPanel(
    contentRect: NSRect(x: 20, y: 20, width: 160, height: 100),
    styleMask: [.borderless, .nonactivatingPanel],
    backing: .buffered,
    defer: false
)
window.level = .floating
window.contentView = NSView(frame: NSRect(x: 0, y: 0, width: 160, height: 100))
window.makeKeyAndOrderFront(nil)
RunLoop.current.run(until: Date().addingTimeInterval(0.15))
let appeared = window.isVisible
print("CI_PANEL_VISIBLE=\(appeared)")
window.orderOut(nil)
window.close()
let closed = !window.isVisible
print("CI_PANEL_CLOSED=\(closed)")
let passed = appeared && closed
print("CI_DESKTOP_PROBE_RESULT=\(passed ? "PASS" : "UNAVAILABLE")")
exit(passed ? 0 : 2)
