import CoreGraphics
import Foundation
import XCTest
@testable import PicPaste

@MainActor
final class SelectionGeometryTests: XCTestCase {
    private func screen(
        frame: CGRect = CGRect(x: 0, y: 0, width: 100, height: 100),
        pixelsWide: Int = 100,
        pixelsHigh: Int = 100
    ) -> DisplayGeometry {
        DisplayGeometry(
            displayID: 42,
            desktopFramePoints: frame,
            imageWidthPixels: pixelsWide,
            imageHeightPixels: pixelsHigh
        )
    }

    func testOneXConvertsAppKitBottomLeftToImageTopLeft() {
        let rect = CGRect(x: 10, y: 20, width: 30, height: 40)
        XCTAssertEqual(
            SelectionGeometry.pixelRect(fromLocalPoints: rect, display: screen()),
            PixelRect(x: 10, y: 40, width: 30, height: 40)
        )
    }

    func testRetinaTwoXUsesLocalPerDisplayPixelDimensions() {
        let rect = CGRect(x: 10, y: 20, width: 30, height: 40)
        XCTAssertEqual(
            SelectionGeometry.pixelRect(fromLocalPoints: rect, display: screen(pixelsWide: 200, pixelsHigh: 200)),
            PixelRect(x: 20, y: 80, width: 60, height: 80)
        )
    }

    func testNegativeGlobalOriginsDoNotChangeLocalPixelRect() {
        let local = CGRect(x: 20, y: 30, width: 50, height: 60)
        let left = screen(frame: CGRect(x: -1920, y: 0, width: 100, height: 100), pixelsWide: 200, pixelsHigh: 200)
        let above = screen(frame: CGRect(x: 0, y: -1080, width: 100, height: 100), pixelsWide: 200, pixelsHigh: 200)
        let normal = screen(pixelsWide: 200, pixelsHigh: 200)
        XCTAssertEqual(SelectionGeometry.pixelRect(fromLocalPoints: local, display: left),
                       SelectionGeometry.pixelRect(fromLocalPoints: local, display: normal))
        XCTAssertEqual(SelectionGeometry.pixelRect(fromLocalPoints: local, display: above),
                       SelectionGeometry.pixelRect(fromLocalPoints: local, display: normal))
    }

    func testClampsOutOfDisplayAreaWithoutNegativePixels() {
        let rect = CGRect(x: -20, y: -30, width: 50, height: 60)
        XCTAssertEqual(
            SelectionGeometry.pixelRect(fromLocalPoints: rect, display: screen(pixelsWide: 200, pixelsHigh: 200)),
            PixelRect(x: 0, y: 140, width: 60, height: 60)
        )
    }

    func testRejectsZeroAreaAndFullyOutsideRects() {
        XCTAssertNil(SelectionGeometry.pixelRect(fromLocalPoints: CGRect(x: 20, y: 20, width: 0, height: 10), display: screen()))
        XCTAssertNil(SelectionGeometry.pixelRect(fromLocalPoints: CGRect(x: 20, y: 20, width: 10, height: 0), display: screen()))
        XCTAssertNil(SelectionGeometry.pixelRect(fromLocalPoints: CGRect(x: -50, y: 10, width: 20, height: 20), display: screen()))
        XCTAssertNil(SelectionGeometry.pixelRect(fromLocalPoints: CGRect(x: 101, y: 10, width: 20, height: 20), display: screen()))
    }

    func testFractionalPixelScaleUsesFloorMinAndCeilMax() {
        let rect = CGRect(x: 1.25, y: 2.25, width: 3, height: 4)
        XCTAssertEqual(
            SelectionGeometry.pixelRect(fromLocalPoints: rect, display: screen(pixelsWide: 150, pixelsHigh: 150)),
            PixelRect(x: 1, y: 140, width: 6, height: 7)
        )
    }

    func testReverseDragCreatesCanonicalPositiveRect() {
        XCTAssertEqual(
            SelectionGeometry.dragRect(from: CGPoint(x: 80, y: 70), to: CGPoint(x: 20, y: 30)),
            CGRect(x: 20, y: 30, width: 60, height: 40)
        )
    }

    func testEightHandlesResizeInAppKitLocalPoints() {
        let start = CGRect(x: 10, y: 20, width: 30, height: 40)
        let cases: [(SelectionHandle, CGPoint, CGRect)] = [
            (.topLeft, CGPoint(x: -5, y: 75), CGRect(x: -5, y: 20, width: 45, height: 55)),
            (.top, CGPoint(x: 15, y: 80), CGRect(x: 10, y: 20, width: 30, height: 60)),
            (.topRight, CGPoint(x: 50, y: 80), CGRect(x: 10, y: 20, width: 40, height: 60)),
            (.right, CGPoint(x: 50, y: 30), CGRect(x: 10, y: 20, width: 40, height: 40)),
            (.bottomRight, CGPoint(x: 50, y: 5), CGRect(x: 10, y: 5, width: 40, height: 55)),
            (.bottom, CGPoint(x: 20, y: 5), CGRect(x: 10, y: 5, width: 30, height: 55)),
            (.bottomLeft, CGPoint(x: -5, y: 5), CGRect(x: -5, y: 5, width: 45, height: 55)),
            (.left, CGPoint(x: -5, y: 20), CGRect(x: -5, y: 20, width: 45, height: 40))
        ]
        XCTAssertEqual(SelectionHandle.allCases.count, 8)
        for (handle, point, expected) in cases {
            XCTAssertEqual(SelectionGeometry.resized(start, handle: handle, to: point), expected, "\(handle)")
        }
    }

    func testHandleCanCrossOppositeEdgeWithoutNegativeSize() {
        let start = CGRect(x: 10, y: 20, width: 30, height: 40)
        let result = SelectionGeometry.resized(start, handle: .left, to: CGPoint(x: 55, y: 30))
        XCTAssertEqual(result, CGRect(x: 40, y: 20, width: 15, height: 40))
    }

    func testMoveIsClampedToLocalDisplayBounds() {
        let moved = SelectionGeometry.moved(
            CGRect(x: 80, y: 80, width: 30, height: 30),
            by: CGPoint(x: 20, y: 20),
            within: CGSize(width: 100, height: 100)
        )
        XCTAssertEqual(moved, CGRect(x: 70, y: 70, width: 30, height: 30))
    }

    func testKnownPixelsMatchCGImageCroppingCoordinates() throws {
        let width = 4
        let height = 4
        var bytes: [UInt8] = []
        for y in 0..<height {
            for x in 0..<width {
                bytes.append(UInt8(10 * y + x))
                bytes.append(UInt8(20 * y + x))
                bytes.append(70)
                bytes.append(255)
            }
        }
        let source = try XCTUnwrap(makeImage(bytes: bytes, width: width, height: height))
        let rect = try XCTUnwrap(
            SelectionGeometry.pixelRect(
                fromLocalPoints: CGRect(x: 1, y: 1, width: 2, height: 2),
                display: screen(frame: CGRect(x: 0, y: 0, width: 4, height: 4), pixelsWide: 4, pixelsHigh: 4)
            )
        )
        XCTAssertEqual(rect, PixelRect(x: 1, y: 1, width: 2, height: 2))
        let clipped = try XCTUnwrap(source.cropping(to: CGRect(x: rect.x, y: rect.y, width: rect.width, height: rect.height)))
        XCTAssertEqual(clipped.width, 2)
        XCTAssertEqual(clipped.height, 2)
        let expected = try XCTUnwrap(renderRGBA(source))
        let actual = try XCTUnwrap(renderRGBA(clipped))
        for y in 0..<rect.height {
            for x in 0..<rect.width {
                let dest = (y * rect.width + x) * 4
                let src = ((y + rect.y) * width + x + rect.x) * 4
                XCTAssertEqual(Array(actual[dest..<(dest + 4)]), Array(expected[src..<(src + 4)]))
            }
        }
    }

    private func makeImage(bytes: [UInt8], width: Int, height: Int) -> CGImage? {
        let data = Data(bytes)
        guard let provider = CGDataProvider(data: data as CFData) else { return nil }
        return CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        )
    }

    private func renderRGBA(_ image: CGImage) -> [UInt8]? {
        let size = image.width * image.height * 4
        var output = [UInt8](repeating: 0, count: size)
        let success = output.withUnsafeMutableBytes { raw -> Bool in
            guard let ctx = CGContext(
                data: raw.baseAddress,
                width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: image.width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            ctx.interpolationQuality = .none
            ctx.translateBy(x: 0, y: CGFloat(image.height))
            ctx.scaleBy(x: 1, y: -1)
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        return success ? output : nil
    }
}
