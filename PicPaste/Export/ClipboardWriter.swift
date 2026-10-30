import AppKit
import Foundation

@MainActor
enum ClipboardWriter {
    @discardableResult
    static func copyPNG(_ data: Data) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setData(data, forType: .png)
    }
}
