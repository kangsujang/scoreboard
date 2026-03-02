import SwiftUI

extension Color {
    static let scoreGold = Color(red: 1.0, green: 0.843, blue: 0.0)

    static func scoreboardBackground(for theme: ScoreboardStyle.Theme) -> Color {
        switch theme {
        case .dark:
            return .black.opacity(0.7)
        case .light:
            return .white.opacity(0.8)
        case .broadcast:
            return Color(red: 0.1, green: 0.1, blue: 0.3).opacity(0.85)
        case .minimal:
            return .black.opacity(0.4)
        }
    }

    static func scoreboardText(for theme: ScoreboardStyle.Theme) -> Color {
        switch theme {
        case .dark, .broadcast, .minimal:
            return .white
        case .light:
            return .black
        }
    }

    static func scoreboardScore(for theme: ScoreboardStyle.Theme) -> Color {
        switch theme {
        case .dark, .broadcast:
            return .scoreGold
        case .light:
            return .blue
        case .minimal:
            return .white
        }
    }
}
