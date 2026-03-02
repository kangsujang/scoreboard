import Foundation
import SwiftData

@Model
final class ScoreEvent {
    var id: UUID
    var teamRawValue: String
    var timestamp: TimeInterval
    var createdAt: Date

    var match: Match?

    var team: Team {
        get { Team(rawValue: teamRawValue) ?? .home }
        set { teamRawValue = newValue.rawValue }
    }

    init(team: Team, timestamp: TimeInterval) {
        self.id = UUID()
        self.teamRawValue = team.rawValue
        self.timestamp = timestamp
        self.createdAt = Date()
    }
}
