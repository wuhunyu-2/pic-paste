import CoreGraphics
import ImageIO
import Foundation
import XCTest
@testable import PicPaste

@MainActor
final class PNGExportTests: XCTestCase {
    private func source(size: Int = 4) throws -> CGImage {
        let pixels: [UInt8] = Array(repeating: [UInt8(90), 120, 150, 255], count: size * size).flatMap { $0 }
        let provider = try XCTUnwrap(CGDataProvider(data: Data(pixels) as CFData))
        return try XCTUnwrap(CGImage(width: size, height: size, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: size * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
    }

    func testRoundedCornerHasTransparentAlpha() throws {
        let output = try ImageComposer.compose(source: source(size: 16), crop: PixelRect(x: 0, y: 0, width: 16, height: 16), radius: 8)
        let png = try PNGExporter.encode(output)
        let decoded = try XCTUnwrap(CGImageSourceCreateWithData(png as CFData, nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(decoded, 0, nil))
        XCTAssertEqual(image.width, 16)
        XCTAssertEqual(image.height, 16)
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 16 * 16 * 4)
        defer { buffer.deallocate() }
        let context = try XCTUnwrap(CGContext(data: buffer, width: 16, height: 16, bitsPerComponent: 8,
            bytesPerRow: 64, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.clear(CGRect(x: 0, y: 0, width: 16, height: 16))
        context.draw(image, in: CGRect(x: 0, y: 0, width: 16, height: 16))
        print("PNG_ALPHA_DIAGNOSTIC corner=\(buffer[3]) center=\(buffer[(8 * 16 + 8) * 4 + 3]) sourceAlpha=\(String(describing: image.alphaInfo))")
        XCTAssertLessThan(buffer[3], 128, "Outer corner must be mostly transparent; edge anti-aliasing is permitted")
        XCTAssertGreaterThan(buffer[(8 * 16 + 8) * 4 + 3], 0, "Center must remain opaque")
    }

    func testCropPreservesSourcePixelDimensions() throws {
        let output = try ImageComposer.compose(source: source(), crop: PixelRect(x: 1, y: 1, width: 2, height: 3), radius: 0)
        XCTAssertEqual(output.width, 2)
        XCTAssertEqual(output.height, 3)
    }

    func testRejectsInvalidCropAndRadius() throws {
        XCTAssertThrowsError(try ImageComposer.compose(source: source(), crop: PixelRect(x: -1, y: 0, width: 2, height: 2), radius: 0))
        XCTAssertThrowsError(try ImageComposer.compose(source: source(), crop: PixelRect(x: 0, y: 0, width: 2, height: 2), radius: 65))
    }

    func testSaveToChosenURLPreservesNameAndRefusesOverwrite() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let target = directory.appendingPathComponent("custom-name.png")
        let png = try PNGExporter.encode(source())
        try PNGExporter.save(png, to: target)
        XCTAssertEqual(try Data(contentsOf: target), png)
        XCTAssertThrowsError(try PNGExporter.save(Data("replacement".utf8), to: target))
        XCTAssertEqual(try Data(contentsOf: target), png)
    }

    func testPNGUniqueFilesNeverOverwrite() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let data = try PNGExporter.encode(source())
        let first = try PNGExporter.save(data, in: directory)
        let second = try PNGExporter.save(data, in: directory)
        XCTAssertNotEqual(first, second)
        XCTAssertEqual(try Data(contentsOf: first), data)
        XCTAssertEqual(try Data(contentsOf: second), data)
    }
}
