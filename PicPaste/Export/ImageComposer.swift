import CoreGraphics
import Foundation

enum ImageComposeError: Error { case invalidCrop, invalidRadius, contextUnavailable }

enum ImageComposer {
    static func compose(source: CGImage, crop: PixelRect, radius: Int) throws -> CGImage {
        guard (0...64).contains(radius) else { throw ImageComposeError.invalidRadius }
        guard crop.x >= 0, crop.y >= 0, crop.width > 0, crop.height > 0,
              crop.x <= source.width, crop.y <= source.height,
              crop.width <= source.width - crop.x, crop.height <= source.height - crop.y,
              let clipped = source.cropping(to: CGRect(x: crop.x, y: crop.y, width: crop.width, height: crop.height))
        else { throw ImageComposeError.invalidCrop }
        if radius == 0 { return clipped }
        let width = clipped.width, height = clipped.height
        let space = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: 0, space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { throw ImageComposeError.contextUnavailable }
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        let adjusted = min(CGFloat(radius), CGFloat(min(width, height)) / 2)
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: adjusted, cornerHeight: adjusted, transform: nil))
        ctx.clip()
        ctx.draw(clipped, in: rect)
        guard let output = ctx.makeImage() else { throw ImageComposeError.contextUnavailable }
        return output
    }
}
