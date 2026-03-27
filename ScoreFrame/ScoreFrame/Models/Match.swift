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
        scoreEvents.filter { $0.team == .home }.count
    }

    var awayScore: Int {
        scoreEvents.filter { $0.team == .away }.count
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
        penaltyTimers
            .filter { $0.team == team && $0.remainingSeconds(at: videoTime) != nil }
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
        var home = 0
        var away = 0
        for event in sortedEvents where event.timestamp <= time {
            switch event.team {
            case .home: home += 1
            case .away: away += 1
            }
        }
        return (home, away)
    }
}
