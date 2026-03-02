import SwiftUI

struct ScoreControlsView: View {
    let match: Match
    let currentTime: TimeInterval
    let onGoal: (Team) -> Void
    let onUndo: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(match.homeTeamName)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text("\(match.homeScore) - \(match.awayScore)")
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .monospacedDigit()
                Spacer()
                Text(match.awayTeamName)
                    .font(.headline)
                    .lineLimit(1)
            }
            .padding(.horizontal)

            Text(TimeFormatting.format(seconds: currentTime))
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                GoalButton(teamName: match.homeTeamName, color: .blue) {
                    onGoal(.home)
                }

                Button {
                    onUndo()
                } label: {
                    Label("取消", systemImage: "arrow.uturn.backward")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .disabled(match.scoreEvents.isEmpty)

                GoalButton(teamName: match.awayTeamName, color: .red) {
                    onGoal(.away)
                }
            }
            .padding(.horizontal)
        }
    }
}

private struct GoalButton: View {
    let teamName: String
    let color: Color
    let action: () -> Void
    @State private var tapCount = 0

    var body: some View {
        Button {
            tapCount += 1
            action()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: "soccerball")
                    .font(.title2)
                Text("ゴール+")
                    .font(.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .tint(color)
        .sensoryFeedback(.impact(weight: .heavy), trigger: tapCount)
    }
}
