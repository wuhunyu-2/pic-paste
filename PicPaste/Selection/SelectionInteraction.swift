import CoreGraphics

/// Screen-local, pure interaction state. No window or image ownership.
struct SelectionInteraction {
    private enum Gesture {
        case drawing(CGPoint)
        case moving(CGPoint, CGRect)
        case resizing(SelectionHandle, CGRect)
    }
    private var gesture: Gesture?
    private var bounds: CGRect = .zero
    private(set) var selection: CGRect?

    mutating func begin(at point: CGPoint, bounds: CGRect) {
        self.bounds = bounds
        let point = clamp(point)
        if let selection {
            if let handle = hitHandle(at: point, rect: selection) {
                gesture = .resizing(handle, selection)
            } else if selection.contains(point) {
                gesture = .moving(point, selection)
            } else {
                gesture = .drawing(point)
                self.selection = .zero
            }
        } else {
            gesture = .drawing(point)
            selection = .zero
        }
    }

    mutating func update(to point: CGPoint) {
        guard let gesture else { return }
        let current = clamp(point)
        switch gesture {
        case .drawing(let origin):
            selection = SelectionGeometry.dragRect(from: origin, to: current)
        case .moving(let origin, let original):
            selection = SelectionGeometry.moved(original, by: CGPoint(x: current.x - origin.x, y: current.y - origin.y), within: bounds.size)
        case .resizing(let handle, let original):
            selection = SelectionGeometry.resized(original, handle: handle, to: current)
        }
    }

    mutating func end() {
        gesture = nil
        if let selection, (selection.width <= 0 || selection.height <= 0) { self.selection = nil }
    }

    mutating func cancel() {
        gesture = nil
        selection = nil
    }

    func confirm(display: DisplayGeometry) -> PixelRect? {
        guard let selection else { return nil }
        return SelectionGeometry.pixelRect(fromLocalPoints: selection, display: display)
    }

    private func clamp(_ point: CGPoint) -> CGPoint {
        CGPoint(x: min(max(point.x, 0), bounds.width), y: min(max(point.y, 0), bounds.height))
    }

    private func hitHandle(at point: CGPoint, rect: CGRect) -> SelectionHandle? {
        let positions: [(SelectionHandle, CGPoint)] = [
            (.topLeft, CGPoint(x: rect.minX, y: rect.maxY)),
            (.top, CGPoint(x: rect.midX, y: rect.maxY)),
            (.topRight, CGPoint(x: rect.maxX, y: rect.maxY)),
            (.right, CGPoint(x: rect.maxX, y: rect.midY)),
            (.bottomRight, CGPoint(x: rect.maxX, y: rect.minY)),
            (.bottom, CGPoint(x: rect.midX, y: rect.minY)),
            (.bottomLeft, CGPoint(x: rect.minX, y: rect.minY)),
            (.left, CGPoint(x: rect.minX, y: rect.midY))
        ]
        return positions.first { abs($0.1.x - point.x) <= 6 && abs($0.1.y - point.y) <= 6 }?.0
    }
}
