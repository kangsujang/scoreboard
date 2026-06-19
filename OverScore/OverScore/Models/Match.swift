import Foundation
import SwiftData

@Model
final class Match {
    var id: UUID
    var homeTeamName: String
    var awayTeamName: String
    var videoBookmark: Data?
    var videoBookmarksData: Data?
    var createdAt: Date
    var scoreboardStyleData: Data?
    var timerStartTime: TimeInterval?   // キックオフの動画内タイムスタンプ（後方互換用）
    var timerStopTime: TimeInterval?    // 試合終了の動画内タイムスタンプ（後方互換用）
    var timerStartOffset: TimeInterval? // タイマー開始時の試合経過時間（後方互換用）
    var timerSegmentsData: Data?        // [TimerSegment] を JSON エンコード保存
    var matchInfo: String?              // 大会名・日程などの試合情報
    var pkKicksData: Data?              // [PKKick] を JSON エンコード保存
    var penaltyTimersData: Data?       // [PenaltyTimer] を JSON エンコード保存
    var timeoutsData: Data?            // [TimeoutEvent] を JSON エンコード保存
    var skipOverlay: Bool = false       // スコアボードオーバーレイを付けず動画のみ結合
    var sportTypeRaw: String?           // SportType (旧データは nil → サッカー扱い)

    var sportType: SportType {
        get { sportTypeRaw.flatMap(SportType.init(rawValue:)) ?? .soccer }
        set { sportTypeRaw = newValue.rawValue }
    }

    @Relationship(deleteRule: .cascade, inverse: \ScoreEvent.match)
    var scoreEvents: [ScoreEvent]

    var scoreboardStyle: ScoreboardStyle {
        get {
            guard let data = scoreboardStyleData,
                  let style = try? JSONDecoder().decode(ScoreboardStyle.self, from: data) else {
                return ScoreboardStyle()
            }
            return style
        }
        set {
            scoreboardStyleData = try? JSONEncoder().encode(newValue)
        }
    }

    var videoURL: URL? {
        get {
            guard let bookmark = videoBookmark else { return nil }
            var isStale = false
            return try? URL(
                resolvingBookmarkData: bookmark,
                bookmarkDataIsStale: &isStale
            )
        }
        set {
            videoBookmark = try? newValue?.bookmarkData()
        }
    }

    var videoURLs: [URL] {
        get {
            // 新形式: videoBookmarksData から復元
            if let data = videoBookmarksData,
               let bookmarks = try? JSONDecoder().decode([Data].self, from: data) {
                let urls = bookmarks.compactMap { bookmark -> URL? in
                    var isStale = false
                    return try? URL(
                        resolvingBookmarkData: bookmark,
                        bookmarkDataIsStale: &isStale
                    )
                }
                if !urls.isEmpty { return urls }
            }
            // 旧形式フォールバック: 単一の videoBookmark
            if let url = videoURL {
                return [url]
            }
            return []
        }
        set {
            let bookmarks = newValue.compactMap { try? $0.bookmarkData() }
            videoBookmarksData = try? JSONEncoder().encode(bookmarks)
            // 後方互換: 最初のURLを旧プロパティにも保存
            videoBookmark = bookmarks.first
        }
    }

    var timerSegments: [TimerSegment] {
        get {
            if let data = timerSegmentsData,
               let segments = try? JSONDecoder().decode([TimerSegment].self, from: data),
               !segments.isEmpty {
                return segments
            }
            // 後方互換: 既存の単一タイマーからセグメント1つを自動生成
            if timerStartTime != nil || timerStopTime != nil || timerStartOffset != nil {
                return [TimerSegment(
                    periodLabel: scoreboardStyle.periodLabel,
                    timerStartTime: timerStartTime,
                    timerStopTime: timerStopTime,
                    timerStartOffset: timerStartOffset
                )]
            }
            return []
        }
        set {
            timerSegmentsData = try? JSONEncoder().encode(newValue)
        }
    }

    func segmentIndex(at videoTime: TimeInterval) -> Int? {
        for (i, seg) in timerSegments.enumerated() {
            guard let start = seg.effectiveStartTime else { continue }
            let end = seg.timerStopTime ?? .infinity
            if videoTime >= start && videoTime <= end {
                return i
            }
        }
        return nil
    }

    func currentPeriodLabel(at videoTime: TimeInterval) -> String? {
        guard let idx = segmentIndex(at: videoTime) else {
            // セグメント外 → 直前のセグメントのラベルを返す
            var lastLabel: String?
            for seg in timerSegments {
                guard let start = seg.effectiveStartTime else { continue }
                if start <= videoTime {
                    lastLabel = seg.periodLabel
                }
            }
            return lastLabel
        }
        return timerSegments[idx].periodLabel
    }

    var homeScore: Int {
        currentScore(for: .home)
    }

    var awayScore: Int {
        currentScore(for: .away)
    }

    /// 現在の累積得点（showSetCount時は最後のセット獲得以降のみカウント）。
    /// 「セクション境界」は最後の .setWon イベント時刻を意味する。
    private func currentScore(for team: Team) -> Int {
        let style = scoreboardStyle
        if style.showSetCount {
            let lastSetWon = scoreEvents
                .filter { $0.kind == .setWon }
                .max(by: { $0.timestamp < $1.timestamp })?.timestamp ?? -1
            return scoreEvents.filter {
                $0.team == team && $0.kind == .point && $0.timestamp > lastSetWon
            }.count
        }
        return scoreEvents.filter { $0.team == team && $0.kind == .point }.count
    }

    var homeSetCount: Int {
        scoreEvents.filter { $0.team == .home && $0.kind == .setWon }.count
    }

    var awaySetCount: Int {
        scoreEvents.filter { $0.team == .away && $0.kind == .setWon }.count
    }

    /// 指定動画時刻時点での累積セット獲得数（バレーボールなど）。
    func effectiveSetCount(at videoTime: TimeInterval, for team: Team) -> Int {
        scoreEvents.filter {
            $0.team == team && $0.kind == .setWon && $0.timestamp <= videoTime
        }.count
    }

    var sortedEvents: [ScoreEvent] {
        scoreEvents.sorted { $0.timestamp < $1.timestamp }
    }

    init(homeTeamName: String, awayTeamName: String) {
        self.id = UUID()
        self.homeTeamName = homeTeamName
        self.awayTeamName = awayTeamName
        self.createdAt = Date()
        self.scoreEvents = []
    }

    var pkKicks: [PKKick] {
        get {
            guard let data = pkKicksData,
                  let kicks = try? JSONDecoder().decode([PKKick].self, from: data) else {
                return []
            }
            return kicks
        }
        set {
            pkKicksData = try? JSONEncoder().encode(newValue)
        }
    }

    var homePKKicks: [PKKick] {
        pkKicks.filter { $0.team == .home }.sorted { $0.order < $1.order }
    }

    var awayPKKicks: [PKKick] {
        pkKicks.filter { $0.team == .away }.sorted { $0.order < $1.order }
    }

    var homePKScore: Int {
        pkKicks.filter { $0.team == .home && $0.isGoal }.count
    }

    var awayPKScore: Int {
        pkKicks.filter { $0.team == .away && $0.isGoal }.count
    }

    func pkKicksAt(time: TimeInterval) -> [PKKick] {
        pkKicks.filter { $0.timestamp <= time }
    }

    func activeTimerSegment(at videoTime: TimeInterval) -> TimerSegment? {
        if let idx = segmentIndex(at: videoTime) {
            return timerSegments[idx]
        }
        // セグメント外 → 直前のアクティブセグメントを返す
        var lastSeg: TimerSegment?
        for seg in timerSegments {
            guard let start = seg.effectiveStartTime else { continue }
            if start <= videoTime { lastSeg = seg }
        }
        return lastSeg
    }

    /// セクション別チームカラーが有効な場合、その時点で有効な色のHex値を返す。
    /// 該当セクションに色設定が無ければスタイル既定値（match.scoreboardStyle のチームカラー）にフォールバック。
    func effectiveTeamColorHex(at videoTime: TimeInterval, for team: Team) -> String? {
        let style = scoreboardStyle
        let baseHex = team == .home ? style.homeTeamColorHex : style.awayTeamColorHex
        guard style.useSegmentTeamColors else { return baseHex }

        // 該当時刻のセクション、または直前にアクティブだったセクションを参照
        let seg = activeTimerSegment(at: videoTime)
        let segHex = team == .home ? seg?.homeTeamColorHex : seg?.awayTeamColorHex
        return segHex ?? baseHex
    }

    // MARK: - Penalty Timers

    var penaltyTimers: [PenaltyTimer] {
        get {
            guard let data = penaltyTimersData,
                  let timers = try? JSONDecoder().decode([PenaltyTimer].self, from: data) else {
                return []
            }
            return timers
        }
        set {
            penaltyTimersData = try? JSONEncoder().encode(newValue)
        }
    }

    func activePenaltyTimers(at videoTime: TimeInterval, for team: Team) -> [PenaltyTimer] {
        let tos = timeouts
        return penaltyTimers
            .filter { $0.team == team && $0.remainingSeconds(at: videoTime, timeouts: tos) != nil }
            .sorted { $0.timestamp < $1.timestamp }
    }

    // MARK: - Timeouts

    var timeouts: [TimeoutEvent] {
        get {
            guard let data = timeoutsData,
                  let events = try? JSONDecoder().decode([TimeoutEvent].self, from: data) else {
                return []
            }
            return events
        }
        set {
            timeoutsData = try? JSONEncoder().encode(newValue)
        }
    }

    func timeoutCount(for team: Team, at videoTime: TimeInterval) -> Int {
        timeouts.filter { $0.team == team && $0.timestamp <= videoTime }.count
    }

    func isTimeoutActive(at videoTime: TimeInterval) -> Bool {
        timeouts.contains { $0.isActive(at: videoTime) }
    }

    func scoreAt(time: TimeInterval) -> (home: Int, away: Int) {
        let style = scoreboardStyle
        // showSetCount時: 指定時刻までの最後の setWon 時刻を境界としてスコアをリセット
        var resetBoundary: TimeInterval = -1
        if style.showSetCount {
            resetBoundary = sortedEvents
                .filter { $0.kind == .setWon && $0.timestamp <= time }
                .last?.timestamp ?? -1
        }

        var home = 0
        var away = 0
        for event in sortedEvents where event.timestamp <= time && event.timestamp > resetBoundary && event.kind == .point {
            switch event.team {
            case .home: home += 1
            case .away: away += 1
            }
        }
        return (home, away)
    }
}
