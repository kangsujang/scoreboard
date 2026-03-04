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
            guard let start = seg.timerStartTime else { continue }
            let end = seg.timerStopTime ?? .infinity
            if videoTime >= start && videoTime <= end {
                return i
            }
        }
        return nil
    }

    func currentPeriodLabel(at videoTime: TimeInterval) -> String? {
        guard let idx = segmentIndex(at: videoTime) else {
            // セグメント外 → 直前のセグメントのラベルを返す（フリーズ区間）
            var lastLabel: String?
            for seg in timerSegments {
                guard let start = seg.timerStartTime else { continue }
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
