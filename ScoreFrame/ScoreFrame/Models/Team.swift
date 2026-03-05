import Foundation

enum Team: String, Codable, CaseIterable {
    case home
    case away
}

struct PKKick: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var team: Team
    var order: Int
    var isGoal: Bool
    var timestamp: TimeInterval
}
