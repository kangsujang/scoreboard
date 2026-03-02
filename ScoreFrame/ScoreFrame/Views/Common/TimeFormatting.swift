import Foundation
import CoreMedia

struct TimeFormatting {
    static func format(seconds: TimeInterval) -> String {
        let totalSeconds = Int(max(0, seconds))
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }

    static func format(cmTime: CMTime) -> String {
        guard cmTime.isValid, !cmTime.isIndefinite else { return "00:00" }
        return format(seconds: cmTime.seconds)
    }
}
