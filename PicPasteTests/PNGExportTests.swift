import CoreGraphics
import ImageIO
import Foundation
import XCTest
@testable import PicPaste

@MainActor
final class PNGExportTests: XCTestCase {
    private func source() throws -> CGImage {
        let pixels: [UInt8] = Array(repeating: [UInt8(90), 120, 150, 255], count: 16).flatMap { $0 }
        let provider = try XCTUnwrap(CGDataProvider(data: Data(pixels) as CFData))
        return try XCTUnwrap(CGImage(width: 4, height: 4, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: 16, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
    }

    func testRoundedCornerHasTransparentAlpha() throws {
        let output = try ImageComposer.compose(source: source(), crop: PixelRect(x: 0, y: 0, width: 4, height: 4), radius: 2)
        let png = try PNGExporter.encode(output)
        let decoded = try XCTUnwrap(CGImageSourceCreateWithData(png as CFData, nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(decoded, 0, nil))
        XCTAssertEqual(image.width, 4)
        XCTAssertEqual(image.height, 4)
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 4 * 4 * 4)
        defer { buffer.deallocate() }
        let context = try XCTUnwrap(CGContext(data: buffer, width: 4, height: 4, bitsPerComponent: 8,
            bytesPerRow: 16, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.clear(CGRect(x: 0, y: 0, width: 4, height: 4))
        context.draw(image, in: CGRect(x: 0, y: 0, width: 4, height: 4))
        XCTAssertEqual(buffer[3], 0, "Top/bottom corner must remain transparent")
        XCTAssertGreaterThan(buffer[(1 * 4 + 1) * 4 + 3], 0, "Interior must not be transparent")
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
