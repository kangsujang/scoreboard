import SwiftUI

struct ScoreControlsView: View {
    let match: Match
    let currentTime: TimeInterval
    let onGoal: (Team) -> Void
    let onUndo: () -> Void
    let onSegmentTimerStart: (Int) -> Void
    let onSegmentTimerStop: (Int) -> Void
    let onSegmentTimerClear: (Int) -> Void
    let onSegmentOffsetChange: (Int, TimeInterval) -> Void
    let onSegmentPeriodLabel: (Int, String?) -> Void
    let onAddSegment: () -> Void
    let onRemoveSegment: (Int) -> Void

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

            // セグメントリスト
            ForEach(Array(match.timerSegments.enumerated()), id: \.offset) { index, segment in
                SegmentControlRow(
                    index: index,
                    segment: segment,
                    onTimerStart: { onSegmentTimerStart(index) },
                    onTimerStop: { onSegmentTimerStop(index) },
                    onTimerClear: { onSegmentTimerClear(index) },
                    onOffsetChange: { onSegmentOffsetChange(index, $0) },
                    onPeriodLabel: { onSegmentPeriodLabel(index, $0) },
                    onRemove: match.timerSegments.count > 1 ? { onRemoveSegment(index) } : nil
                )
            }

            // セグメント追加ボタン
            Button {
                onAddSegment()
            } label: {
                Label("セグメント追加", systemImage: "plus.circle")
                    .font(.caption2.weight(.semibold))
            }
            .buttonStyle(.bordered)
            .tint(.blue)
            .padding(.horizontal)
        }
    }
}

// MARK: - Segment Control Row

private struct SegmentControlRow: View {
    let index: Int
    let segment: TimerSegment
    let onTimerStart: () -> Void
    let onTimerStop: () -> Void
    let onTimerClear: () -> Void
    let onOffsetChange: (TimeInterval) -> Void
    let onPeriodLabel: (String?) -> Void
    let onRemove: (() -> Void)?

    private var totalOffsetSeconds: Int { Int(segment.timerStartOffset ?? 0) }
    private var offsetMinutes: Int { totalOffsetSeconds / 60 }
    private var offsetSeconds: Int { totalOffsetSeconds % 60 }

    var body: some View {
        VStack(spacing: 6) {
            // ヘッダー
            HStack {
                Text("セグメント \(index + 1)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                Spacer()
                if let onRemove {
                    Button(role: .destructive) {
                        onRemove()
                    } label: {
                        Image(systemName: "trash.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                }
            }

            // ピリオドプリセット
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(["前半", "後半", "延前", "延後", "PK"], id: \.self) { preset in
                        Button(preset) {
                            onPeriodLabel(segment.periodLabel == preset ? nil : preset)
                        }
                        .buttonStyle(.bordered)
                        .tint(segment.periodLabel == preset ? .accentColor : .secondary)
                        .controlSize(.small)
                    }
                }
            }

            // タイマー操作行
            HStack(spacing: 8) {
                Button {
                    onTimerStart()
                } label: {
                    VStack(spacing: 2) {
                        Label("キックオフ", systemImage: "play.circle")
                            .font(.caption2.weight(.semibold))
                        if let start = segment.timerStartTime {
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
                        if let stop = segment.timerStopTime {
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
                .disabled(segment.timerStartTime == nil)

                if segment.timerStartTime != nil || segment.timerStopTime != nil {
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

            // 開始時間オフセット調整行 (MM:SS)
            if segment.timerStartTime != nil {
                HStack(spacing: 4) {
                    Text("開始時間")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Spacer()

                    // 分の調整
                    Button {
                        onOffsetChange(TimeInterval((offsetMinutes - 1) * 60 + offsetSeconds))
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
                        onOffsetChange(TimeInterval((offsetMinutes + 1) * 60 + offsetSeconds))
                    } label: {
                        Image(systemName: "plus.circle")
                            .font(.caption)
                    }

                    Text(":")
                        .font(.caption.weight(.medium))

                    // 秒の調整
                    Button {
                        onOffsetChange(TimeInterval(offsetMinutes * 60 + offsetSeconds - 1))
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
                            onOffsetChange(TimeInterval((offsetMinutes + 1) * 60))
                        } else {
                            onOffsetChange(TimeInterval(offsetMinutes * 60 + newSeconds))
                        }
                    } label: {
                        Image(systemName: "plus.circle")
                            .font(.caption)
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary)
        )
        .padding(.horizontal)
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
