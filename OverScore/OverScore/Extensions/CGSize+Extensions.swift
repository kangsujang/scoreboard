import CoreGraphics
import AVFoundation

extension CGSize {
    /// Returns the natural video size corrected for preferredTransform rotation.
    static func correctedVideoSize(from track: AVAssetTrack) -> CGSize {
        let size = track.naturalSize
        let transform = track.preferredTransform
        let isRotated = abs(transform.b) == 1 && abs(transform.c) == 1
        if isRotated {
            return CGSize(width: size.height, height: size.width)
        }
        return size
    }
}
