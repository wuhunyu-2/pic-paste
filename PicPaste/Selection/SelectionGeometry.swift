import CoreGraphics

/// Display-local source-image coordinates: origin at top-left, [min, max)
/// on both axes. Width/height are strictly positive for valid crop regions.
struct PixelRect: Equatable {
    let x: Int
    let y: Int
    let width: Int
    let height: Int
}

enum SelectionHandle: CaseIterable {
    case topLeft, top, topRight, right
    case bottomRight, bottom, bottomLeft, left
}

/// Pure transformations only. All input rectangles use the display-local
/// AppKit points coordinate system (bottom-left origin, y increases up).
enum SelectionGeometry {
    static func dragRect(from start: CGPoint, to end: CGPoint) -> CGRect {
        CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
    }

    static func resized(_ initial: CGRect, handle: SelectionHandle, to location: CGPoint) -> CGRect {
        let rect = initial.standardized
        var left = rect.minX
        var right = rect.maxX
        var bottom = rect.minY
        var top = rect.maxY

        switch handle {
        case .topLeft:     left = location.x; top = location.y
        case .top:         top = location.y
        case .topRight:    right = location.x; top = location.y
        case .right:       right = location.x
        case .bottomRight: right = location.x; bottom = location.y
        case .bottom:      bottom = location.y
        case .bottomLeft:  left = location.x; bottom = location.y
        case .left:        left = location.x
        }

        return CGRect(
            x: min(left, right),
            y: min(bottom, top),
            width: abs(right - left),
            height: abs(top - bottom)
        )
    }

    static func moved(_ initial: CGRect, by delta: CGPoint, within size: CGSize) -> CGRect {
        let rect = initial.standardized
        let maxX = max(0, size.width - rect.width)
        let maxY = max(0, size.height - rect.height)
        return CGRect(
            x: min(max(0, rect.minX + delta.x), maxX),
            y: min(max(0, rect.minY + delta.y), maxY),
            width: rect.width,
            height: rect.height
        )
    }

    /// Convert a local AppKit selection into the *original* CGImage pixels.
    /// Clip to the display first; floor both min edges, ceil both max edges,
    /// and clamp to the half-open image dimensions. Never multiply any global
    /// desktop origin by Retina scale.
    static func pixelRect(
        fromLocalPoints selection: CGRect,
        display: DisplayGeometry
    ) -> PixelRect? {
        let frame = display.desktopFramePoints
        let pointWidth = frame.width
        let pointHeight = frame.height
        let pixelWidth = display.imageWidthPixels
        let pixelHeight = display.imageHeightPixels

        guard pixelWidth > 0, pixelHeight > 0,
              pointWidth.isFinite, pointHeight.isFinite,
              pointWidth > 0, pointHeight > 0,
              selection.minX.isFinite, selection.minY.isFinite,
              selection.maxX.isFinite, selection.maxY.isFinite else {
            return nil
        }

        let local = selection.standardized
        let displayBounds = CGRect(x: 0, y: 0, width: pointWidth, height: pointHeight)
        let clipped = local.intersection(displayBounds)
        guard !clipped.isNull, clipped.width > 0, clipped.height > 0 else {
            return nil
        }

        let scaleX = CGFloat(pixelWidth) / pointWidth
        let scaleY = CGFloat(pixelHeight) / pointHeight
        guard scaleX.isFinite, scaleY.isFinite else { return nil }

        // AppKit selection is y-up. The source image's crop rect is y-down.
        let left = floor(clipped.minX * scaleX)
        let right = ceil(clipped.maxX * scaleX)
        let top = floor((pointHeight - clipped.maxY) * scaleY)
        let bottom = ceil((pointHeight - clipped.minY) * scaleY)
        guard left.isFinite, right.isFinite, top.isFinite, bottom.isFinite else {
            return nil
        }

        let maxWidth = CGFloat(pixelWidth)
        let maxHeight = CGFloat(pixelHeight)
        let x0 = Int(min(max(0, left), maxWidth))
        let x1 = Int(min(max(0, right), maxWidth))
        let y0 = Int(min(max(0, top), maxHeight))
        let y1 = Int(min(max(0, bottom), maxHeight))
        guard x1 > x0, y1 > y0 else { return nil }
        return PixelRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)
    }
}
