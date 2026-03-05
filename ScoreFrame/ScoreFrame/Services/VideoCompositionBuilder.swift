import AVFoundation
import CoreGraphics

enum VideoCompositionBuilder {

    struct Result {
        let composition: AVMutableComposition
        let videoSize: CGSize
        let duration: CMTime
        let segmentTransforms: [(track: AVMutableCompositionTrack, transform: CGAffineTransform, naturalSize: CGSize)]
        let nominalFrameRate: Float
    }

    enum BuildError: LocalizedError {
        case noURLs
        case noVideoTrack(URL)
        case trackCreationFailed

        var errorDescription: String? {
            switch self {
            case .noURLs:
                return "動画URLが指定されていません"
            case .noVideoTrack(let url):
                return "動画トラックが見つかりません: \(url.lastPathComponent)"
            case .trackCreationFailed:
                return "コンポジショントラックの作成に失敗しました"
            }
        }
    }

    // MARK: - Build Composition

    static func build(from urls: [URL]) async throws -> Result {
        guard !urls.isEmpty else { throw BuildError.noURLs }

        let composition = AVMutableComposition()

        guard let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw BuildError.trackCreationFailed
        }

        let compositionAudioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )

        var currentTime = CMTime.zero
        var referenceSize: CGSize?
        var referenceFrameRate: Float?
        var segments: [(track: AVMutableCompositionTrack, transform: CGAffineTransform, naturalSize: CGSize)] = []

        for url in urls {
            let asset = AVURLAsset(url: url)

            let videoTracks = try await asset.loadTracks(withMediaType: .video)
            guard let sourceVideoTrack = videoTracks.first else {
                throw BuildError.noVideoTrack(url)
            }

            let duration = try await asset.load(.duration)
            let timeRange = CMTimeRange(start: .zero, duration: duration)
            let naturalSize = try await sourceVideoTrack.load(.naturalSize)
            let preferredTransform = try await sourceVideoTrack.load(.preferredTransform)

            try compositionVideoTrack.insertTimeRange(timeRange, of: sourceVideoTrack, at: currentTime)

            let audioTracks = try await asset.loadTracks(withMediaType: .audio)
            if let sourceAudioTrack = audioTracks.first, let audioTrack = compositionAudioTrack {
                try audioTrack.insertTimeRange(timeRange, of: sourceAudioTrack, at: currentTime)
            }

            let corrected = correctedSize(naturalSize: naturalSize, transform: preferredTransform)
            if referenceSize == nil {
                referenceSize = corrected
                referenceFrameRate = try await sourceVideoTrack.load(.nominalFrameRate)
            }

            segments.append((
                track: compositionVideoTrack,
                transform: preferredTransform,
                naturalSize: naturalSize
            ))

            currentTime = CMTimeAdd(currentTime, duration)
        }

        let videoSize = referenceSize ?? CGSize(width: 1920, height: 1080)
        let frameRate = (referenceFrameRate ?? 0) > 0 ? referenceFrameRate! : 30.0

        return Result(
            composition: composition,
            videoSize: videoSize,
            duration: currentTime,
            segmentTransforms: segments,
            nominalFrameRate: frameRate
        )
    }

    // MARK: - Video Composition (Layer Instructions)

    static func makeVideoComposition(
        result: Result,
        videoLayer: CALayer,
        parentLayer: CALayer
    ) -> AVMutableVideoComposition {
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = result.videoSize
        let timescale = Int32(ceil(result.nominalFrameRate))
        videoComposition.frameDuration = CMTime(value: 1, timescale: timescale)
        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videoLayer,
            in: parentLayer
        )

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: result.duration)

        // 最初のセグメントの transform を使用（全セグメント同一トラック）
        if let first = result.segmentTransforms.first {
            let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: first.track)
            layerInstruction.setTransform(
                correctedTransform(first.transform, naturalSize: first.naturalSize),
                at: .zero
            )
            instruction.layerInstructions = [layerInstruction]
        }

        videoComposition.instructions = [instruction]
        return videoComposition
    }

    // MARK: - Transform Handling

    static func correctedSize(naturalSize: CGSize, transform: CGAffineTransform) -> CGSize {
        let isRotated = abs(transform.b) == 1 && abs(transform.c) == 1
        if isRotated {
            return CGSize(width: naturalSize.height, height: naturalSize.width)
        }
        return naturalSize
    }

    static func correctedTransform(_ transform: CGAffineTransform, naturalSize: CGSize) -> CGAffineTransform {
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
