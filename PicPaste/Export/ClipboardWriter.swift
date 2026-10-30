import AppKit
import Foundation

@MainActor
enum ClipboardWriter {
    @discardableResult
    static func copyPNG(_ data: Data, to pasteboard: NSPasteboard = .general) -> Bool {
        pasteboard.clearContents()
        return pasteboard.setData(data, forType: .png)
    }
}
