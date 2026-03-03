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

    private var baseFontSize: CGFloat { 16 }
}
