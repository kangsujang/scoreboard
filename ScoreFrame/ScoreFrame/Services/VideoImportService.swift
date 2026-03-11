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

    /// Documents/Videos/ 内の孤立ファイル（どのMatchからも参照されていない）を削除
    static func cleanupOrphanedVideos(referencedURLs: Set<URL>) {
        let fileManager = FileManager.default
        let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let videosDir = documentsDir.appendingPathComponent("Videos", isDirectory: true)

        guard let files = try? fileManager.contentsOfDirectory(
            at: videosDir,
            includingPropertiesForKeys: nil
        ) else { return }

        for file in files {
            if !referencedURLs.contains(file) {
                try? fileManager.removeItem(at: file)
            }
        }
    }

    /// /tmp/ 内の ScoreFrame エクスポート一時ファイルを削除
    static func cleanupTempExportFiles() {
        let fileManager = FileManager.default
        let tmpDir = fileManager.temporaryDirectory

        guard let files = try? fileManager.contentsOfDirectory(
            at: tmpDir,
            includingPropertiesForKeys: nil
        ) else { return }

        for file in files {
            if file.lastPathComponent.hasPrefix("ScoreFrame_") && file.pathExtension == "mp4" {
                try? fileManager.removeItem(at: file)
            }
        }
    }
}
