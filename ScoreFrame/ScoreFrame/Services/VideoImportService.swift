import Foundation
import AVFoundation

struct VideoImportService {
    static func copyToSandbox(from sourceURL: URL) async throws -> URL {
        let fileManager = FileManager.default
        let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let videosDir = documentsDir.appendingPathComponent("Videos", isDirectory: true)

        if !fileManager.fileExists(atPath: videosDir.path) {
            try fileManager.createDirectory(at: videosDir, withIntermediateDirectories: true)
        }

        let fileName = "\(UUID().uuidString).\(sourceURL.pathExtension)"
        let destinationURL = videosDir.appendingPathComponent(fileName)

        let accessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        return destinationURL
    }

    static func deleteVideo(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}
