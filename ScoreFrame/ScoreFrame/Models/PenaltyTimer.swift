import Foundation

struct PenaltyTimer: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var team: Team
    var timestamp: TimeInterval      // 動画内のペナルティ開始時刻
    var durationSeconds: TimeInterval // カウントダウン秒数 (120, 300, 600)

    /// 動画内のペナルティ終了時刻
    var expiresAt: TimeInterval {
        timestamp + durationSeconds
    }

    /// 指定動画時刻での残り秒数。未開始 or 終了時は nil
    func remainingSeconds(at videoTime: TimeInterval) -> TimeInterval? {
        guard videoTime >= timestamp else { return nil }
        let remaining = durationSeconds - (videoTime - timestamp)
        return remaining > 0 ? remaining : nil
    }
}
