import Foundation
import Photos

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

        PHPhotoLibrary.requestAuthorization(for: .addOnly) { [weak self] status in
            guard status == .authorized || status == .limited else {
                Task { @MainActor in
                    self?.saveError = "写真ライブラリへのアクセスが許可されていません"
                }
                return
            }

            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            } completionHandler: { success, error in
                Task { @MainActor in
                    if success {
                        self?.savedToPhotos = true
                    } else {
                        self?.saveError = error?.localizedDescription ?? "保存に失敗しました"
                    }
                }
            }
        }
    }
}
