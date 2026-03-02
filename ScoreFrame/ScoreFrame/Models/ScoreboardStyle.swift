import Foundation

struct ScoreboardStyle: Codable, Equatable {
    var position: Position = .topLeft
    var theme: Theme = .dark
    var fontSize: FontSize = .medium
    var showMatchTimer: Bool = true

    enum Position: String, Codable, CaseIterable {
        case topLeft
        case topCenter
        case topRight

        var displayName: String {
            switch self {
            case .topLeft: return "左上"
            case .topCenter: return "中央上"
            case .topRight: return "右上"
            }
        }
    }

    enum Theme: String, Codable, CaseIterable {
        case dark
        case light
        case broadcast
        case minimal

        var displayName: String {
            switch self {
            case .dark: return "Dark"
            case .light: return "Light"
            case .broadcast: return "Broadcast"
            case .minimal: return "Minimal"
            }
        }
    }

    enum FontSize: String, Codable, CaseIterable {
        case small
        case medium
        case large

        var displayName: String {
            switch self {
            case .small: return "小"
            case .medium: return "中"
            case .large: return "大"
            }
        }

        var scaleFactor: CGFloat {
            switch self {
            case .small: return 0.75
            case .medium: return 1.0
            case .large: return 1.3
            }
        }
    }
}
