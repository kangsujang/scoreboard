import Foundation
import SwiftData

enum ScoreEventKind: String, Codable, CaseIterable {
    case point   // 通常の得点（ラリー単位など）
    case setWon  // セット獲得（バレーボール等）
}

@Model
final class ScoreEvent {
    var id: UUID
    var teamRawValue: String
    var timestamp: TimeInterval
    var createdAt: Date
    /// イベント種別。既存レコードは既定で .point になるよう Optional + フォールバックで扱う
    var kindRawValue: String?

    var match: Match?

    var team: Team {
        get { Team(rawValue: teamRawValue) ?? .home }
        set { teamRawValue = newValue.rawValue }
    }

    var kind: ScoreEventKind {
        get { ScoreEventKind(rawValue: kindRawValue ?? "") ?? .point }
        set { kindRawValue = newValue.rawValue }
    }

    init(team: Team, timestamp: TimeInterval, kind: ScoreEventKind = .point) {
        self.id = UUID()
        self.teamRawValue = team.rawValue
        self.timestamp = timestamp
        self.createdAt = Date()
        self.kindRawValue = kind.rawValue
    }
}
