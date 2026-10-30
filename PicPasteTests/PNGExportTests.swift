import CoreGraphics
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

    func testCropPreservesSourcePixelDimensions() throws {
        let output = try ImageComposer.compose(source: source(), crop: PixelRect(x: 1, y: 1, width: 2, height: 3), radius: 0)
        XCTAssertEqual(output.width, 2)
        XCTAssertEqual(output.height, 3)
    }

    func testRejectsInvalidCropAndRadius() throws {
        XCTAssertThrowsError(try ImageComposer.compose(source: source(), crop: PixelRect(x: -1, y: 0, width: 2, height: 2), radius: 0))
        XCTAssertThrowsError(try ImageComposer.compose(source: source(), crop: PixelRect(x: 0, y: 0, width: 2, height: 2), radius: 65))
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
