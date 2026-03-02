import SwiftUI

struct ScoreboardPreviewView: View {
    let homeTeamName: String
    let awayTeamName: String
    let homeScore: Int
    let awayScore: Int
    let style: ScoreboardStyle

    var body: some View {
        ZStack {
            // Simulated video background
            Rectangle()
                .fill(.green.opacity(0.3))
                .overlay {
                    Image(systemName: "sportscourt")
                        .font(.system(size: 60))
                        .foregroundStyle(.green.opacity(0.2))
                }

            // Scoreboard overlay
            VStack {
                HStack {
                    if style.position == .topRight {
                        Spacer()
                    }

                    scoreboardContent

                    if style.position == .topLeft {
                        Spacer()
                    }
                }
                .padding(8)
                Spacer()
            }
        }
        .aspectRatio(16/9, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var scoreboardContent: some View {
        HStack(spacing: 6) {
            Text(homeTeamName)
                .font(.system(size: baseFontSize * 0.7, weight: .medium))

            Text("\(homeScore) - \(awayScore)")
                .font(.system(size: baseFontSize, weight: .bold, design: .rounded))
                .foregroundStyle(Color.scoreboardScore(for: style.theme))

            Text(awayTeamName)
                .font(.system(size: baseFontSize * 0.7, weight: .medium))

            if style.showMatchTimer {
                Text("32:15")
                    .font(.system(size: baseFontSize * 0.6, weight: .regular, design: .monospaced))
            }
        }
        .foregroundStyle(Color.scoreboardText(for: style.theme))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.scoreboardBackground(for: style.theme))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var baseFontSize: CGFloat {
        switch style.fontSize {
        case .small: return 12
        case .medium: return 16
        case .large: return 20
        }
    }
}
