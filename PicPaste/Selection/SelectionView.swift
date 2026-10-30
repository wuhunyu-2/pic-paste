import AppKit

@MainActor
final class SelectionView: NSView {
    private let frame: CapturedFrame
    private var interaction = SelectionInteraction()
    var onComplete: ((PixelRect?) -> Void)?
    private var completed = false

    init(frame: CapturedFrame) {
        self.frame = frame
        super.init(frame: CGRect(origin: .zero, size: frame.geometry.desktopFramePoints.size))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is unsupported") }
    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.draw(frame.image, in: bounds)
        context.setFillColor(NSColor.black.withAlphaComponent(0.35).cgColor)
        context.fill(bounds)
        if let selected = interaction.selection {
            context.saveGState()
            context.clip(to: selected)
            context.draw(frame.image, in: bounds)
            context.restoreGState()
            context.setStrokeColor(NSColor.systemBlue.cgColor)
            context.setLineWidth(2)
            context.stroke(selected)
            context.setFillColor(NSColor.white.cgColor)
            for point in handlePoints(for: selected) {
                context.fill(CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6))
            }
        }
    }

    private func handlePoints(for rect: CGRect) -> [CGPoint] {
        [CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.midX, y: rect.minY),
         CGPoint(x: rect.maxX, y: rect.minY), CGPoint(x: rect.minX, y: rect.midY),
         CGPoint(x: rect.maxX, y: rect.midY), CGPoint(x: rect.minX, y: rect.maxY),
         CGPoint(x: rect.midX, y: rect.maxY), CGPoint(x: rect.maxX, y: rect.maxY)]
    }

    override func mouseDown(with event: NSEvent) {
        interaction.begin(at: convert(event.locationInWindow, from: nil), bounds: bounds)
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        interaction.update(to: convert(event.locationInWindow, from: nil))
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        interaction.update(to: convert(event.locationInWindow, from: nil))
        interaction.end()
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53: complete(nil)
        case 36, 76:
            if let pixelRect = interaction.confirm(display: frame.geometry) { complete(pixelRect) }
        default: super.keyDown(with: event)
        }
    }

    func cancel() { complete(nil) }

    private func complete(_ result: PixelRect?) {
        guard !completed else { return }
        completed = true
        onComplete?(result)
    }
}
