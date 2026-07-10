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

    static func creationDate(for url: URL) async -> Date? {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing { url.stopAccessingSecurityScopedResource() }
        }
        let asset = AVURLAsset(url: url)
        if let items = try? await asset.load(.metadata) {
            if let item = items.first(where: { $0.commonKey == .commonKeyCreationDate }),
               let dateValue = try? await item.load(.value) {
                if let date = dateValue as? Date {
                    return date
                }
                if let str = try? await item.load(.stringValue),
                   let date = ISO8601DateFormatter().date(from: str) {
                    return date
                }
            }
        }
        let values = try? url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
        return values?.creationDate ?? values?.contentModificationDate
    }

    static func deleteVideo(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    struct VideoInfo {
        let dimensions: CGSize
        let frameRate: Float
    }

    /// 動画ファイルから表示用のメタ情報（補正済み解像度・AVFoundationが報告する生のフレームレート）を取得する。
    static func videoInfo(for url: URL) async -> VideoInfo? {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing { url.stopAccessingSecurityScopedResource() }
        }
        let asset = AVURLAsset(url: url)
        do {
            let tracks = try await asset.loadTracks(withMediaType: .video)
            guard let track = tracks.first else { return nil }
            let naturalSize = try await track.load(.naturalSize)
            let transform = try await track.load(.preferredTransform)
            let nominal = try await track.load(.nominalFrameRate)
            let minFrameDuration = try await track.load(.minFrameDuration)
            let durationBased: Float = (minFrameDuration.isValid && minFrameDuration.seconds > 0)
                ? Float(1.0 / minFrameDuration.seconds)
                : 0
            let dimensions = VideoCompositionBuilder.correctedSize(naturalSize: naturalSize, transform: transform)
            return VideoInfo(dimensions: dimensions, frameRate: max(nominal, durationBased))
        } catch {
            return nil
        }
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

    /// /tmp/ 内の OverScore エクスポート一時ファイルを削除
    static func cleanupTempExportFiles() {
        let fileManager = FileManager.default
        let tmpDir = fileManager.temporaryDirectory

        guard let files = try? fileManager.contentsOfDirectory(
            at: tmpDir,
            includingPropertiesForKeys: nil
        ) else { return }

        for file in files {
            if file.lastPathComponent.hasPrefix("OverScore_") && file.pathExtension == "mp4" {
                try? fileManager.removeItem(at: file)
            }
        }
    }
}
