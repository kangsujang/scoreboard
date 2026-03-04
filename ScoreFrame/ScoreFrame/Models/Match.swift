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
    var timerStartTime: TimeInterval?   // キックオフの動画内タイムスタンプ
    var timerStopTime: TimeInterval?    // 試合終了の動画内タイムスタンプ
    var timerStartOffset: TimeInterval? // タイマー開始時の試合経過時間（秒）例: 後半開始=2700

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
