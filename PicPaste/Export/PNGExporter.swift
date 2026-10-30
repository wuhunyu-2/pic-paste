import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum PNGExportError: Error { case encodingFailed, fileCollision }

enum PNGExporter {
    static func encode(_ image: CGImage) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)
        else { throw PNGExportError.encodingFailed }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw PNGExportError.encodingFailed }
        return data as Data
    }

    static func save(_ data: Data, in directory: URL) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for _ in 0..<10 {
            let filename = "PicPaste-\(ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-"))-\(UUID().uuidString).png"
            let target = directory.appendingPathComponent(filename)
            let temp = directory.appendingPathComponent(".\(UUID().uuidString).tmp")
            try data.write(to: temp, options: .atomic)
            defer { try? FileManager.default.removeItem(at: temp) }
            // POSIX link creates destination only if it does not yet exist.
            if link(temp.path, target.path) == 0 { return target }
            if errno != EEXIST { throw CocoaError(.fileWriteUnknown) }
        }
        throw PNGExportError.fileCollision
    }
}
