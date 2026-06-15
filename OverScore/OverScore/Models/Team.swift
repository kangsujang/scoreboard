import Foundation

enum Team: String, Codable, CaseIterable, Identifiable {
    case home
    case away

    var id: String { rawValue }
}

struct PKKick: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var team: Team
    var order: Int
    var isGoal: Bool
    var timestamp: TimeInterval
}
