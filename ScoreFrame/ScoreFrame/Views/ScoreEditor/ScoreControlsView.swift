import SwiftUI

struct ScoreControlsView: View {
    let match: Match
    let currentTime: TimeInterval
    let onGoal: (Team) -> Void
    let onUndo: () -> Void
    let onTimerStart: () -> Void
    let onTimerStop: () -> Void
    let onTimerClear: () -> Void
    let onTimerOffsetChange: (TimeInterval) -> Void

    private var totalOffsetSeconds: Int {
        Int(match.timerStartOffset ?? 0)
    }

    private var offsetMinutes: Int { totalOffsetSeconds / 60 }
    private var offsetSeconds: Int { totalOffsetSeconds % 60 }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(match.homeTeamName)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer()
                Text("\(match.homeScore) - \(match.awayScore)")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .monospacedDigit()
                Spacer()
                Text(match.awayTeamName)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal)

            Text(TimeFormatting.format(seconds: currentTime))
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                GoalButton(teamName: match.homeTeamName, color: .blue) {
                    onGoal(.home)
                }

                Button {
                    onUndo()
                } label: {
                    Label("取消", systemImage: "arrow.uturn.backward")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .disabled(match.scoreEvents.isEmpty)

                GoalButton(teamName: match.awayTeamName, color: .red) {
                    onGoal(.away)
                }
            }
            .padding(.horizontal)

            // タイマー操作行
            HStack(spacing: 8) {
                Button {
                    onTimerStart()
                } label: {
                    VStack(spacing: 2) {
                        Label("キックオフ", systemImage: "play.circle")
                            .font(.caption2.weight(.semibold))
                        if let start = match.timerStartTime {
                            Text(TimeFormatting.format(seconds: start))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .tint(.green)

                Button {
                    onTimerStop()
                } label: {
                    VStack(spacing: 2) {
                        Label("試合終了", systemImage: "stop.circle")
                            .font(.caption2.weight(.semibold))
                        if let stop = match.timerStopTime {
                            Text(TimeFormatting.format(seconds: stop))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .tint(.orange)
                .disabled(match.timerStartTime == nil)

                if match.timerStartTime != nil || match.timerStopTime != nil {
                    Button {
                        onTimerClear()
                    } label: {
                        Image(systemName: "xmark.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .tint(.secondary)
                }
            }
            .padding(.horizontal)

            // 開始時間オフセット調整行 (MM:SS)
            if match.timerStartTime != nil {
                HStack(spacing: 4) {
                    Text("開始時間")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Spacer()

                    // 分の調整
                    Button {
                        onTimerOffsetChange(TimeInterval((offsetMinutes - 1) * 60 + offsetSeconds))
                    } label: {
                        Image(systemName: "minus.circle")
                            .font(.caption)
                    }
                    .disabled(offsetMinutes <= 0)

                    Text(String(format: "%02d", offsetMinutes))
                        .font(.caption.weight(.medium))
                        .monospacedDigit()
                        .frame(minWidth: 22)

                    Button {
                        onTimerOffsetChange(TimeInterval((offsetMinutes + 1) * 60 + offsetSeconds))
                    } label: {
                        Image(systemName: "plus.circle")
                            .font(.caption)
                    }

                    Text(":")
                        .font(.caption.weight(.medium))

                    // 秒の調整
                    Button {
                        onTimerOffsetChange(TimeInterval(offsetMinutes * 60 + offsetSeconds - 1))
                    } label: {
                        Image(systemName: "minus.circle")
                            .font(.caption)
                    }
                    .disabled(totalOffsetSeconds <= 0)

                    Text(String(format: "%02d", offsetSeconds))
                        .font(.caption.weight(.medium))
                        .monospacedDigit()
                        .frame(minWidth: 22)

                    Button {
                        let newSeconds = offsetSeconds + 1
                        if newSeconds >= 60 {
                            onTimerOffsetChange(TimeInterval((offsetMinutes + 1) * 60))
                        } else {
                            onTimerOffsetChange(TimeInterval(offsetMinutes * 60 + newSeconds))
                        }
                    } label: {
                        Image(systemName: "plus.circle")
                            .font(.caption)
                    }
                }
                .padding(.horizontal)
            }
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
            VStack(spacing: 2) {
                Image(systemName: "soccerball")
                    .font(.title3)
                Text("ゴール+")
                    .font(.caption2.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
        .tint(color)
        .sensoryFeedback(.impact(weight: .heavy), trigger: tapCount)
    }
}
