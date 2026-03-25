import AVFoundation
import UIKit

@MainActor
@Observable
final class VideoExportService {
    private(set) var progress: Float = 0
    private(set) var isExporting = false
    private(set) var exportedURL: URL?
    private(set) var error: Error?

    private var exportSession: AVAssetExportSession?
    private var progressTimer: Timer?
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    enum ExportError: LocalizedError {
        case noVideoTrack
        case exportSessionCreationFailed
        case exportFailed(String)
        case cancelled

        var errorDescription: String? {
            switch self {
            case .noVideoTrack:
                return String(localized: "動画トラックが見つかりません")
            case .exportSessionCreationFailed:
                return String(localized: "エクスポートセッションの作成に失敗しました")
            case .exportFailed(let reason):
                return String(localized: "エクスポートに失敗: \(reason)")
            case .cancelled:
                return String(localized: "エクスポートがキャンセルされました")
            }
        }
    }

    func export(match: Match) async throws -> URL {
        let urls = match.videoURLs
        guard !urls.isEmpty else {
            throw ExportError.noVideoTrack
        }

        isExporting = true
        progress = 0
        exportedURL = nil
        error = nil
        UIApplication.shared.isIdleTimerDisabled = true
        beginBackgroundTask()

        do {
            let url = try await performExport(
                urls: urls,
                match: match
            )
            exportedURL = url
            isExporting = false
            progress = 1.0
            UIApplication.shared.isIdleTimerDisabled = false
            endBackgroundTask()
            return url
        } catch {
            self.error = error
            isExporting = false
            UIApplication.shared.isIdleTimerDisabled = false
            endBackgroundTask()
            throw error
        }
    }

    func cancel() {
        exportSession?.cancelExport()
        progressTimer?.invalidate()
        progressTimer = nil
    }

    func cleanupExportedFile() {
        guard let url = exportedURL else { return }
        try? FileManager.default.removeItem(at: url)
        exportedURL = nil
    }

    // MARK: - Core Export Pipeline

    private func performExport(urls: [URL], match: Match) async throws -> URL {
        let result = try await VideoCompositionBuilder.build(from: urls)
        let videoSize = result.videoSize

        // Export
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScoreFrame_\(UUID().uuidString)")
            .appendingPathExtension("mp4")

        if match.skipOverlay {
            // オーバーレイなし: Passthroughで高速エクスポート
            guard let session = AVAssetExportSession(
                asset: result.composition,
                presetName: AVAssetExportPresetPassthrough
            ) else {
                throw ExportError.exportSessionCreationFailed
            }

            session.outputURL = outputURL
            session.outputFileType = .mp4

            self.exportSession = session
            startProgressMonitoring(session: session)

            await session.export()

            progressTimer?.invalidate()
            progressTimer = nil

            switch session.status {
            case .completed:
                return outputURL
            case .cancelled:
                throw ExportError.cancelled
            case .failed:
                throw ExportError.exportFailed(session.error?.localizedDescription ?? "Unknown error")
            default:
                throw ExportError.exportFailed("Unexpected status: \(session.status.rawValue)")
            }
        }

        // オーバーレイあり: 通常エクスポート
        let videoDuration = result.duration.seconds

        let style = match.scoreboardStyle
        let config = ScoreboardLayerBuilder.Config(
            homeTeamName: match.homeTeamName,
            awayTeamName: match.awayTeamName,
            events: match.sortedEvents,
            style: style,
            videoSize: videoSize,
            videoDuration: videoDuration,
            timerSegments: match.timerSegments,
            homeTeamColor: style.homeTeamColor.flatMap { UIColor($0).cgColor },
            awayTeamColor: style.awayTeamColor.flatMap { UIColor($0).cgColor },
            matchInfo: match.matchInfo,
            pkKicks: match.pkKicks
        )

        let parentLayer = CALayer()
        parentLayer.frame = CGRect(origin: .zero, size: videoSize)
        parentLayer.isGeometryFlipped = true

        let videoLayer = CALayer()
        videoLayer.frame = CGRect(origin: .zero, size: videoSize)
        parentLayer.addSublayer(videoLayer)

        let overlayLayer = ScoreboardLayerBuilder.buildOverlayLayer(config: config)
        parentLayer.addSublayer(overlayLayer)

        let videoComposition = VideoCompositionBuilder.makeVideoComposition(
            result: result,
            videoLayer: videoLayer,
            parentLayer: parentLayer
        )

        guard let session = AVAssetExportSession(
            asset: result.composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw ExportError.exportSessionCreationFailed
        }

        session.videoComposition = videoComposition
        session.outputURL = outputURL
        session.outputFileType = .mp4

        self.exportSession = session

        // Start progress monitoring
        startProgressMonitoring(session: session)

        await session.export()

        progressTimer?.invalidate()
        progressTimer = nil

        switch session.status {
        case .completed:
            return outputURL
        case .cancelled:
            throw ExportError.cancelled
        case .failed:
            throw ExportError.exportFailed(session.error?.localizedDescription ?? "Unknown error")
        default:
            throw ExportError.exportFailed("Unexpected status: \(session.status.rawValue)")
        }
    }

    // MARK: - Background Task

    private func beginBackgroundTask() {
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "ScoreFrameExport") { [weak self] in
            // 期限切れ時はキャンセルせずバックグラウンドタスクのみ終了
            // AVAssetExportSessionはシステムレベルで継続される
            self?.endBackgroundTask()
        }
    }

    private func endBackgroundTask() {
        guard backgroundTaskID != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
    }

    private func startProgressMonitoring(session: AVAssetExportSession) {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            let currentProgress = session.progress
            Task { @MainActor in
                self?.progress = currentProgress
            }
        }
    }
}
