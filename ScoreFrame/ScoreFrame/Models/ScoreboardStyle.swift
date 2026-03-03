import Foundation
import SwiftUI

struct ScoreboardStyle: Codable, Equatable {
    var theme: Theme = .dark
    var showMatchTimer: Bool = true

    // チームユニフォームカラー ("#RRGGBB" 形式、nil=テーマデフォルト)
    var homeTeamColorHex: String?
    var awayTeamColorHex: String?

    // 連続位置 (0〜1 正規化, 左上原点)
    var positionX: CGFloat = 0.02
    var positionY: CGFloat = 0.02

    // 連続スケール (0.5〜2.5)
    var scale: CGFloat = 1.0

    // 旧プロパティ — Codable 互換のため残す（UIからは使わない）
    var position: Position = .topLeft
    var fontSize: FontSize = .medium

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

    // MARK: - Codable (旧データ互換)

    // MARK: - Computed Color accessors

    var homeTeamColor: Color? {
        get { homeTeamColorHex.flatMap { Color(hex: $0) } }
        set { homeTeamColorHex = newValue?.hexString }
    }

    var awayTeamColor: Color? {
        get { awayTeamColorHex.flatMap { Color(hex: $0) } }
        set { awayTeamColorHex = newValue?.hexString }
    }

    enum CodingKeys: String, CodingKey {
        case theme, showMatchTimer, positionX, positionY, scale, position, fontSize
        case homeTeamColorHex, awayTeamColorHex
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        theme = try container.decodeIfPresent(Theme.self, forKey: .theme) ?? .dark
        showMatchTimer = try container.decodeIfPresent(Bool.self, forKey: .showMatchTimer) ?? true
        positionX = try container.decodeIfPresent(CGFloat.self, forKey: .positionX) ?? 0.02
        positionY = try container.decodeIfPresent(CGFloat.self, forKey: .positionY) ?? 0.02
        scale = try container.decodeIfPresent(CGFloat.self, forKey: .scale) ?? 1.0
        position = try container.decodeIfPresent(Position.self, forKey: .position) ?? .topLeft
        fontSize = try container.decodeIfPresent(FontSize.self, forKey: .fontSize) ?? .medium
        homeTeamColorHex = try container.decodeIfPresent(String.self, forKey: .homeTeamColorHex)
        awayTeamColorHex = try container.decodeIfPresent(String.self, forKey: .awayTeamColorHex)
    }
}
