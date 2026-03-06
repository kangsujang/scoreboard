import SwiftUI

struct ScoreboardPreviewView: View {
    let homeTeamName: String
    let awayTeamName: String
    let homeScore: Int
    let awayScore: Int
    let style: ScoreboardStyle
    var currentPeriodLabel: String? = nil
    var matchInfo: String? = nil
    var pkKicks: [PKKick] = []
    var thumbnail: UIImage? = nil
    var videoAspectRatio: CGFloat = 16.0 / 9.0

    /// プレビューとエクスポートで共通の比率定数
    /// baseFontSize = containerWidth * baseRatio
    static let baseRatio: CGFloat = 0.044

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

                // Scoreboard overlay + PK
                VStack(alignment: .leading, spacing: geo.size.width * Self.baseRatio * 0.25) {
                    scoreboardContent(containerWidth: geo.size.width)

                    if currentPeriodLabel?.lowercased() == "pk", !pkKicks.isEmpty {
                        pkContent(containerWidth: geo.size.width)
                    }
                }
                .scaleEffect(style.scale, anchor: .topLeading)
                .offset(
                    x: style.positionX * geo.size.width,
                    y: style.positionY * geo.size.height
                )

                // 試合情報（独立位置・スケール）
                if let info = matchInfo, !info.isEmpty {
                    matchInfoContent(info: info, containerWidth: geo.size.width)
                        .scaleEffect(style.matchInfoScale, anchor: .topLeading)
                        .offset(
                            x: style.matchInfoPositionX * geo.size.width,
                            y: style.matchInfoPositionY * geo.size.height
                        )
                }
            }
        }
        .aspectRatio(videoAspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func scoreboardContent(containerWidth: CGFloat) -> some View {
        let base = containerWidth * Self.baseRatio
        // メインセクション（スコア丸 + 上下パディング）で決まる高さ
        let containerH = base * 1.4 + base * 0.3125 * 2

        return HStack(spacing: 0) {
            // Period label (e.g. 前半, 後半) — leftmost, white bg / black text
            if let label = currentPeriodLabel, !label.isEmpty {
                Text(label)
                    .font(.system(size: base * 0.55, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, base * 0.375)
                    .frame(maxHeight: .infinity)
                    .background(.white)
            }

            // Timer section (inverted: light bg, dark text)
            // PK中はタイマーを非表示
            if style.showMatchTimer, currentPeriodLabel?.lowercased() != "pk" {
                Text("00:00")
                    .font(.system(size: base * 0.6, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.scoreboardTimerText(for: style.theme))
                    .padding(.horizontal, base * 0.5)
                    .frame(maxHeight: .infinity)
                    .background(Color.scoreboardText(for: style.theme))
            }

            // Main section: team names + score circles
            HStack(spacing: base * 0.375) {
                // Home team name with underline
                teamLabel(
                    name: homeTeamName,
                    color: style.homeTeamColor ?? Color.scoreboardScore(for: style.theme),
                    base: base
                )

                if style.showScore {
                    // Home score circle
                    scoreCircle(homeScore, base: base)
                    // Away score circle
                    scoreCircle(awayScore, base: base)
                } else {
                    Text("vs")
                        .font(.system(size: base * 0.6, weight: .semibold))
                        .foregroundStyle(Color.scoreboardText(for: style.theme).opacity(0.6))
                }

                // Away team name with underline
                teamLabel(
                    name: awayTeamName,
                    color: style.awayTeamColor ?? Color.scoreboardScore(for: style.theme),
                    base: base
                )
            }
            .padding(.horizontal, base * 0.5)
            .padding(.vertical, base * 0.3125)
        }
        .frame(height: containerH)
        .fixedSize(horizontal: true, vertical: false)
        .background(Color.scoreboardBackground(for: style.theme))
        .clipShape(RoundedRectangle(cornerRadius: base * 0.375))
    }

    private func matchInfoContent(info: String, containerWidth: CGFloat) -> some View {
        let base = containerWidth * Self.baseRatio
        return Text(info)
            .font(.system(size: base * 0.45, weight: .medium))
            .foregroundStyle(Color.scoreboardText(for: style.theme))
            .padding(.horizontal, base * 0.5)
            .padding(.vertical, base * 0.2)
            .background(Color.scoreboardBackground(for: style.theme))
            .clipShape(RoundedRectangle(cornerRadius: base * 0.375))
    }

    private func teamLabel(name: String, color: Color, base: CGFloat) -> some View {
        VStack(spacing: base * 0.125) {
            Text(name)
                .font(.system(size: base * 0.65, weight: .semibold))
                .foregroundStyle(Color.scoreboardText(for: style.theme))
                .lineLimit(1)

            Rectangle()
                .fill(color)
                .frame(height: base * 0.125)
        }
        .padding(.horizontal, base * 0.65 * 2) // 2文字分の余白
    }

    private func scoreCircle(_ score: Int, base: CGFloat) -> some View {
        Text("\(score)")
            .font(.system(size: base * 0.85, weight: .bold))
            .foregroundStyle(Color.scoreboardTimerText(for: style.theme))
            .contentTransition(.numericText())
            .frame(width: base * 1.4, height: base * 1.4)
            .background(Circle().fill(Color.scoreboardText(for: style.theme)))
            .scaleEffect(1.0)
            .animation(.bouncy(duration: 0.4, extraBounce: 0.2), value: score)
    }

    // MARK: - PK Display

    private func pkContent(containerWidth: CGFloat) -> some View {
        let base = containerWidth * Self.baseRatio
        let homePK = pkKicks.filter { $0.team == .home }.sorted { $0.order < $1.order }
        let awayPK = pkKicks.filter { $0.team == .away }.sorted { $0.order < $1.order }

        return VStack(alignment: .leading, spacing: base * 0.2) {
            pkRow(teamName: homeTeamName, kicks: homePK, base: base)
            pkRow(teamName: awayTeamName, kicks: awayPK, base: base)
        }
        .padding(.horizontal, base * 0.4)
        .padding(.vertical, base * 0.25)
        .background(Color.scoreboardBackground(for: style.theme))
        .clipShape(RoundedRectangle(cornerRadius: base * 0.375))
    }

    private func pkRow(teamName: String, kicks: [PKKick], base: CGFloat) -> some View {
        HStack(spacing: base * 0.15) {
            Text(teamName)
                .font(.system(size: base * 0.5, weight: .semibold))
                .foregroundStyle(Color.scoreboardText(for: style.theme))
                .lineLimit(1)
                .frame(minWidth: base * 2.5, alignment: .leading)
            ForEach(kicks) { kick in
                Text(kick.isGoal ? "◯" : "✗")
                    .font(.system(size: base * 0.55, weight: .bold))
                    .foregroundStyle(kick.isGoal ? .green : .red)
                    .frame(width: base * 0.7)
            }
        }
    }
}
