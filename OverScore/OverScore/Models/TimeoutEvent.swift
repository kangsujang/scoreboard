import Foundation

struct TimeoutEvent: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var team: Team
    var timestamp: TimeInterval       // タイムアウト開始（動画内時刻）
    var endTimestamp: TimeInterval?    // タイムアウト終了（nil = まだ進行中）

    func isActive(at videoTime: TimeInterval) -> Bool {
        guard videoTime >= timestamp else { return false }
        if let end = endTimestamp { return videoTime < end }
        return true // 終了未設定 = 進行中
    }

    func elapsedSeconds(at videoTime: TimeInterval) -> TimeInterval? {
        guard videoTime >= timestamp else { return nil }
        if let end = endTimestamp, videoTime >= end { return nil }
        return videoTime - timestamp
    }

    /// kickoff〜videoTime の間にこのタイムアウトが停止させた累計秒数
    func pausedSeconds(from kickoff: TimeInterval, to videoTime: TimeInterval) -> TimeInterval {
        let overlapStart = max(timestamp, kickoff)
        let overlapEnd: TimeInterval
        if let end = endTimestamp {
            overlapEnd = min(end, videoTime)
        } else {
            overlapEnd = videoTime
        }
        return max(0, overlapEnd - overlapStart)
    }
}
