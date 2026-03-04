import Foundation

struct TimerSegment: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var periodLabel: String?
    var timerStartTime: TimeInterval?
    var timerStopTime: TimeInterval?
    var timerStartOffset: TimeInterval?
}
