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

    enum ExportError: LocalizedError {
        case noVideoTrack
        case exportSessionCreationFailed
        case exportFailed(String)
        case cancelled

        var errorDescription: String? {
            switch self {
            case .noVideoTrack:
                return "動画トラックが見つかりません"
            case .exportSessionCreationFailed:
                return "エクスポートセッションの作成に失敗しました"
            case .exportFailed(let reason):
                return "エクスポートに失敗: \(reason)"
            case .cancelled:
                return "エクスポートがキャンセルされました"
            }
        }
    }

    func export(match: Match) async throws -> URL {
        guard let videoURL = match.videoURL else {
            throw ExportError.noVideoTrack
        }

        isExporting = true
        progress = 0
        exportedURL = nil
        error = nil

        do {
            let url = try await performExport(
                videoURL: videoURL,
                match: match
            )
            exportedURL = url
            isExporting = false
            progress = 1.0
            return url
        } catch {
            self.error = error
            isExporting = false
            throw error
        }
    }

    func cancel() {
        exportSession?.cancelExport()
        progressTimer?.invalidate()
        progressTimer = nil
    }

    // MARK: - Core Export Pipeline

    private func performExport(videoURL: URL, match: Match) async throws -> URL {
        let asset = AVURLAsset(url: videoURL)
        let composition = AVMutableComposition()

        // Load tracks
        let videoTracks = try await asset.loadTracks(withMediaType: .video)
        guard let sourceVideoTrack = videoTracks.first else {
            throw ExportError.noVideoTrack
        }

        let duration = try await asset.load(.duration)
        let timeRange = CMTimeRange(start: .zero, duration: duration)

        // Add video track
        guard let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw ExportError.exportSessionCreationFailed
        }
        try compositionVideoTrack.insertTimeRange(timeRange, of: sourceVideoTrack, at: .zero)

        // Add audio track if available
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        if let sourceAudioTrack = audioTracks.first,
           let compositionAudioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
           ) {
            try compositionAudioTrack.insertTimeRange(timeRange, of: sourceAudioTrack, at: .zero)
        }

        // Get corrected video size
        let naturalSize = try await sourceVideoTrack.load(.naturalSize)
        let preferredTransform = try await sourceVideoTrack.load(.preferredTransform)
        let videoSize = Self.correctedSize(naturalSize: naturalSize, transform: preferredTransform)

        // Apply preferred transform to composition track
        compositionVideoTrack.preferredTransform = preferredTransform

        // Build layer tree
        let videoDuration = duration.seconds

        let style = match.scoreboardStyle
        let config = ScoreboardLayerBuilder.Config(
            homeTeamName: match.homeTeamName,
            awayTeamName: match.awayTeamName,
            events: match.sortedEvents,
            style: style,
            videoSize: videoSize,
            videoDuration: videoDuration,
            timerStartTime: match.timerStartTime,
            timerStopTime: match.timerStopTime,
            timerStartOffset: match.timerStartOffset,
            homeTeamColor: style.homeTeamColor.flatMap { UIColor($0).cgColor },
            awayTeamColor: style.awayTeamColor.flatMap { UIColor($0).cgColor }
        )

        let parentLayer = CALayer()
        parentLayer.frame = CGRect(origin: .zero, size: videoSize)
        parentLayer.isGeometryFlipped = true

        let videoLayer = CALayer()
        videoLayer.frame = CGRect(origin: .zero, size: videoSize)
        parentLayer.addSublayer(videoLayer)

        let overlayLayer = ScoreboardLayerBuilder.buildOverlayLayer(config: config)
        parentLayer.addSublayer(overlayLayer)

        // Create video composition
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = videoSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videoLayer,
            in: parentLayer
        )

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = timeRange

        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionVideoTrack)
        layerInstruction.setTransform(
            Self.correctedTransform(preferredTransform, naturalSize: naturalSize),
            at: .zero
        )
        instruction.layerInstructions = [layerInstruction]

        videoComposition.instructions = [instruction]

        // Export
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScoreFrame_\(UUID().uuidString)")
            .appendingPathExtension("mp4")

        guard let session = AVAssetExportSession(
            asset: composition,
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

    private func startProgressMonitoring(session: AVAssetExportSession) {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.progress = session.progress
            }
        }
    }

    // MARK: - Transform Handling

    private static func correctedSize(naturalSize: CGSize, transform: CGAffineTransform) -> CGSize {
        let isRotated = abs(transform.b) == 1 && abs(transform.c) == 1
        if isRotated {
            return CGSize(width: naturalSize.height, height: naturalSize.width)
        }
        return naturalSize
    }

    private static func correctedTransform(_ transform: CGAffineTransform, naturalSize: CGSize) -> CGAffineTransform {
        let a = transform.a
        let b = transform.b
        let c = transform.c
        let d = transform.d

        // 90° clockwise (common for portrait iPhone videos)
        if a == 0 && b == 1 && c == -1 && d == 0 {
            return CGAffineTransform(translationX: naturalSize.height, y: 0)
                .rotated(by: .pi / 2)
        }

        // 90° counter-clockwise
        if a == 0 && b == -1 && c == 1 && d == 0 {
            return CGAffineTransform(translationX: 0, y: naturalSize.width)
                .rotated(by: -.pi / 2)
        }

        // 180° rotation
        if a == -1 && b == 0 && c == 0 && d == -1 {
            return CGAffineTransform(translationX: naturalSize.width, y: naturalSize.height)
                .rotated(by: .pi)
        }

        return .identity
    }
}
