import SwiftUI

struct ScoreboardPreviewView: View {
    let homeTeamName: String
    let awayTeamName: String
    let homeScore: Int
    let awayScore: Int
    let style: ScoreboardStyle
    var thumbnail: UIImage? = nil

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                // Video thumbnail or placeholder background
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(.green.opacity(0.3))
                        .overlay {
                            Image(systemName: "sportscourt")
                                .font(.system(size: 60))
                                .foregroundStyle(.green.opacity(0.2))
                        }
                }

                // Scoreboard overlay
                scoreboardContent
                    .scaleEffect(style.scale, anchor: .topLeading)
                    .offset(
                        x: style.positionX * geo.size.width,
                        y: style.positionY * geo.size.height
                    )
            }
        }
        .aspectRatio(16/9, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var scoreboardContent: some View {
        HStack(spacing: 0) {
            // Timer section (inverted: light bg, dark text) — LEFT side
            if style.showMatchTimer {
                Text("00:00")
                    .font(.system(size: baseFontSize * 0.6, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.scoreboardTimerText(for: style.theme))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.scoreboardText(for: style.theme))
            }

            // Main section: team names + score circles
            HStack(spacing: 6) {
                // Home team name with underline
                teamLabel(
                    name: homeTeamName,
                    color: style.homeTeamColor ?? Color.scoreboardScore(for: style.theme)
                )

                // Home score circle
                scoreCircle(homeScore)
                // Away score circle
                scoreCircle(awayScore)

                // Away team name with underline
                teamLabel(
                    name: awayTeamName,
                    color: style.awayTeamColor ?? Color.scoreboardScore(for: style.theme)
                )
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
        }
        .fixedSize()
        .background(Color.scoreboardBackground(for: style.theme))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func teamLabel(name: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(name)
                .font(.system(size: baseFontSize * 0.65, weight: .semibold))
                .foregroundStyle(Color.scoreboardText(for: style.theme))
                .lineLimit(1)

            Rectangle()
                .fill(color)
                .frame(height: 2)
        }
    }

    private func scoreCircle(_ score: Int) -> some View {
        Text("\(score)")
            .font(.system(size: baseFontSize * 0.85, weight: .bold))
            .foregroundStyle(Color.scoreboardTimerText(for: style.theme))
            .frame(width: baseFontSize * 1.4, height: baseFontSize * 1.4)
            .background(Circle().fill(Color.scoreboardText(for: style.theme)))
    }

    private var baseFontSize: CGFloat { 16 }
}
