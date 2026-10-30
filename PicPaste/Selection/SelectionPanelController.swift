import AppKit

/// Owns the frozen selection overlay and guarantees a single completion.
@MainActor
final class SelectionPanelController: NSObject, NSWindowDelegate {
    private var panel: NSPanel?
    private var selectionView: SelectionView?
    private var onComplete: ((PixelRect?) -> Void)?

    func present(frame: CapturedFrame, completion: @escaping (PixelRect?) -> Void) {
        dismiss()
        onComplete = completion
        let window = NSPanel(
            contentRect: frame.geometry.desktopFramePoints,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.level = .screenSaver
        window.collectionBehavior = [.fullScreenAuxiliary, .canJoinAllSpaces]
        window.isOpaque = true
        window.backgroundColor = .black
        window.hasShadow = false
        window.delegate = self
        let view = SelectionView(frame: frame)
        view.onComplete = { [weak self] result in self?.finish(result) }
        window.contentView = view
        panel = window
        selectionView = view
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(view)
    }

    func dismiss() {
        let window = panel
        panel = nil
        selectionView = nil
        onComplete = nil
        window?.delegate = nil
        window?.orderOut(nil)
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        finish(nil)
    }

    private func finish(_ result: PixelRect?) {
        guard let completion = onComplete else { return }
        dismiss()
        completion(result)
    }
}
