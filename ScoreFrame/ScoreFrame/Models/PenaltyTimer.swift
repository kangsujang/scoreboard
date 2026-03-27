import Foundation

struct PenaltyTimer: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var team: Team
    var timestamp: TimeInterval      // 動画内のペナルティ開始時刻
    var durationSeconds: TimeInterval // カウントダウン秒数 (120, 300, 600)

    /// 動画内のペナルティ終了時刻（タイムアウト無視）
    var expiresAt: TimeInterval {
        timestamp + durationSeconds
    }

    /// 指定動画時刻での残り秒数（タイムアウト無視）。未開始 or 終了時は nil
    func remainingSeconds(at videoTime: TimeInterval) -> TimeInterval? {
        guard videoTime >= timestamp else { return nil }
        let remaining = durationSeconds - (videoTime - timestamp)
        return remaining > 0 ? remaining : nil
    }

    /// タイムアウト中もペナルティタイマーを停止させる残り秒数計算
    func remainingSeconds(at videoTime: TimeInterval, timeouts: [TimeoutEvent]) -> TimeInterval? {
        guard videoTime >= timestamp else { return nil }
        var paused: TimeInterval = 0
        for timeout in timeouts {
            paused += timeout.pausedSeconds(from: timestamp, to: videoTime)
        }
        let effectiveElapsed = (videoTime - timestamp) - paused
        let remaining = durationSeconds - effectiveElapsed
        return remaining > 0 ? remaining : nil
    }

    /// タイムアウト累積停止を考慮した実際のペナルティ終了動画時刻
    func effectiveExpiresAt(timeouts: [TimeoutEvent]) -> TimeInterval {
        var end = expiresAt
        for _ in 0..<10 {
            let totalPaused = timeouts.reduce(TimeInterval(0)) { sum, timeout in
                sum + timeout.pausedSeconds(from: timestamp, to: end)
            }
            let newEnd = timestamp + durationSeconds + totalPaused
            if abs(newEnd - end) < 0.001 { return newEnd }
            end = newEnd
        }
        return end
    }
}
