import AVFoundation
import CoreGraphics

enum VideoCompositionBuilder {

    struct Result {
        let composition: AVMutableComposition
        let videoSize: CGSize
        let duration: CMTime
        let segmentTransforms: [(track: AVMutableCompositionTrack, transform: CGAffineTransform, naturalSize: CGSize)]
        /// 元動画のフレーム間隔。29.97fps のようなドロップフレームレートを
        /// 1001/30000 の有理数のまま保持する（整数丸めによるコマ重複を防ぐため）。
        let frameDuration: CMTime

        var nominalFrameRate: Float {
            let seconds = frameDuration.seconds
            return seconds > 0 ? Float(1.0 / seconds) : 30.0
        }
    }

    enum BuildError: LocalizedError {
        case noURLs
        case noVideoTrack(URL)
        case trackCreationFailed

        var errorDescription: String? {
            switch self {
            case .noURLs:
                return String(localized: "動画URLが指定されていません")
            case .noVideoTrack(let url):
                return String(localized: "動画トラックが見つかりません: \(url.lastPathComponent)")
            case .trackCreationFailed:
                return String(localized: "コンポジショントラックの作成に失敗しました")
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
        var shortestFrameDuration: CMTime?
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
            }

            // 複数動画を連結する場合、最もフレームレートの高い素材に合わせる。
            // 低い方に合わせるとその素材のコマが間引かれてカクつくため。
            let segmentFrameDuration = try await detectFrameDuration(of: sourceVideoTrack)
            if let current = shortestFrameDuration {
                shortestFrameDuration = CMTimeMinimum(current, segmentFrameDuration)
            } else {
                shortestFrameDuration = segmentFrameDuration
            }

            segments.append((
                track: compositionVideoTrack,
                transform: preferredTransform,
                naturalSize: naturalSize
            ))

            currentTime = CMTimeAdd(currentTime, duration)
        }

        let videoSize = referenceSize ?? CGSize(width: 1920, height: 1080)
        let frameDuration = shortestFrameDuration ?? defaultFrameDuration

        return Result(
            composition: composition,
            videoSize: videoSize,
            duration: currentTime,
            segmentTransforms: segments,
            frameDuration: frameDuration
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
        videoComposition.frameDuration = result.frameDuration
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

    // MARK: - Video Composition (Without Overlay)

    static func makeVideoCompositionWithoutOverlay(
        result: Result
    ) -> AVMutableVideoComposition {
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = result.videoSize
        videoComposition.frameDuration = result.frameDuration

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: result.duration)

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

    // MARK: - Frame Rate Detection

    static let defaultFrameDuration = CMTime(value: 1, timescale: 30)

    /// 標準的なフレームレートと、それに対応する正確なフレーム間隔。
    /// 29.97 / 59.94 などのドロップフレームレートは 1001/30000 形式の有理数で保持する。
    /// 30 に丸めてしまうと約1000フレームに1枚コマが重複し、周期的なカクつきの原因になる。
    private static let standardFrameDurations: [(rate: Float, duration: CMTime)] = [
        (24000.0 / 1001.0, CMTime(value: 1001, timescale: 24000)),
        (24, CMTime(value: 1, timescale: 24)),
        (25, CMTime(value: 1, timescale: 25)),
        (30000.0 / 1001.0, CMTime(value: 1001, timescale: 30000)),
        (30, CMTime(value: 1, timescale: 30)),
        (50, CMTime(value: 1, timescale: 50)),
        (60000.0 / 1001.0, CMTime(value: 1001, timescale: 60000)),
        (60, CMTime(value: 1, timescale: 60)),
        (100, CMTime(value: 1, timescale: 100)),
        (120000.0 / 1001.0, CMTime(value: 1001, timescale: 120000)),
        (120, CMTime(value: 1, timescale: 120)),
        (240, CMTime(value: 1, timescale: 240))
    ]

    /// 元動画のフレーム間隔を検出する。
    /// nominalFrameRate と minFrameDuration の両方を考慮し、
    /// 4K iPhone素材などで実値より低く（例: 30FPS素材なのに15.79）報告されるケースを救済する。
    static func detectFrameDuration(of track: AVAssetTrack) async throws -> CMTime {
        let nominal = try await track.load(.nominalFrameRate)
        let minFrameDuration = try await track.load(.minFrameDuration)

        let hasMinFrameDuration = minFrameDuration.isValid
            && !minFrameDuration.isIndefinite
            && minFrameDuration.seconds > 0
        let minFrameDurationRate = hasMinFrameDuration ? Float(1.0 / minFrameDuration.seconds) : 0

        let rawRate = max(nominal, minFrameDurationRate)

        // 標準値付近ならドロップフレームレートも区別して正確な有理数を採用する
        if let exact = nearestStandardFrameDuration(for: rawRate, tolerance: 0.1) {
            return exact
        }

        // VFR素材でフレームレートが 1/2・1/3・1/4 に報告されるケースを救済する
        for multiplier: Float in [2, 3, 4] {
            if let exact = nearestStandardFrameDuration(for: rawRate * multiplier, tolerance: 2.0) {
                return exact
            }
        }

        // 標準値に該当しない場合は素材のタイミングをそのまま維持する
        if hasMinFrameDuration && minFrameDurationRate >= nominal {
            return minFrameDuration
        }
        if rawRate > 0 {
            return CMTime(value: 1000, timescale: Int32((rawRate * 1000).rounded()))
        }
        return defaultFrameDuration
    }

    /// 指定フレームレートに最も近い標準フレーム間隔を返す。許容範囲外なら nil。
    static func nearestStandardFrameDuration(for rate: Float, tolerance: Float) -> CMTime? {
        guard rate > 0 else { return nil }
        let nearest = standardFrameDurations.min { abs($0.rate - rate) < abs($1.rate - rate) }
        guard let nearest, abs(nearest.rate - rate) <= tolerance else { return nil }
        return nearest.duration
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
