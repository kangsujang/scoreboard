import Foundation
import Photos

@MainActor
@Observable
final class ExportViewModel {
    let match: Match
    let exportService = VideoExportService()

    var showShareSheet = false
    var savedToPhotos = false
    var saveError: String?

    init(match: Match) {
        self.match = match
    }

    var progress: Float { exportService.progress }
    var isExporting: Bool { exportService.isExporting }
    var exportedURL: URL? { exportService.exportedURL }
    var exportError: Error? { exportService.error }

    func startExport() {
        Task {
            do {
                _ = try await exportService.export(match: match)
            } catch {
                // Error is captured in exportService.error
            }
        }
    }

    func cancelExport() {
        exportService.cancel()
    }

    func saveToPhotos() {
        guard let url = exportedURL else { return }
        saveError = nil

        Task {
            do {
                try await PhotoLibrarySaver.save(videoAt: url)
                savedToPhotos = true
            } catch PhotoLibrarySaver.SaveError.notAuthorized {
                saveError = "写真ライブラリへのアクセスが許可されていません。設定アプリから許可してください。"
            } catch {
                saveError = error.localizedDescription
            }
        }
    }
}

// Nonisolated helper to avoid @MainActor leaking into PHPhotoLibrary's @Sendable closure
private enum PhotoLibrarySaver {
    enum SaveError: LocalizedError {
        case notAuthorized

        var errorDescription: String? {
            "写真ライブラリへのアクセスが許可されていません"
        }
    }

    static func save(videoAt url: URL) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw SaveError.notAuthorized
        }

        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
        }
    }
}
