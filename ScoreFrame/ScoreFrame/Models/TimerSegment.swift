import Foundation

struct TimerSegment: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var periodLabel: String?
    var segmentStartTime: TimeInterval?  // 区切り開始（ピリオド切替・タイマー初期値表示）
    var timerStartTime: TimeInterval?    // キックオフ（タイマー計測開始）
    var timerStopTime: TimeInterval?
    var timerStartOffset: TimeInterval?

    // タイマー表示オプション
    var showPlusPrefix: Bool = false     // "+MM:SS" 形式で表示
    var timerColorHex: String? = nil     // タイマー文字色 ("#RRGGBB")

    /// ピリオド切替・タイマー表示の起点。segmentStartTime が未設定なら timerStartTime を使う
    var effectiveStartTime: TimeInterval? {
        segmentStartTime ?? timerStartTime
    }
}
