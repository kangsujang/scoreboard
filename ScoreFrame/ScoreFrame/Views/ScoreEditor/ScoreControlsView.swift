import SwiftUI

struct ScoreControlsView: View {
    let match: Match
    let currentTime: TimeInterval
    let onGoal: (Team) -> Void
    let onUndo: () -> Void
    let onPKKick: (Team, Bool) -> Void
    let onPKUndo: () -> Void
    let onSegmentStart: (Int) -> Void
    let onSegmentTimerStart: (Int) -> Void
    let onSegmentTimerStop: (Int) -> Void
    let onSegmentTimerClear: (Int) -> Void
    let onSegmentOffsetChange: (Int, TimeInterval) -> Void
    let onSegmentPeriodLabel: (Int, String?) -> Void
    let onSegmentShowPlusPrefix: (Int, Bool) -> Void
    let onSegmentTimerColor: (Int, String?) -> Void
    let onAddSegment: () -> Void
    let onAddSegmentWithRestart: () -> Void
    let onRemoveSegment: (Int) -> Void
    let onAddPenaltyTimer: (Team, TimeInterval) -> Void
    let onRemovePenaltyTimer: (UUID) -> Void
    let onStartTimeout: (Team) -> Void
    let onEndTimeout: (UUID, TimeInterval) -> Void
    let onRemoveTimeout: (UUID) -> Void

    static let periodPresets: [String] = [
        String(localized: "前半"),
        String(localized: "後半"),
        String(localized: "延前"),
        String(localized: "延後"),
        "PK"
    ]

    private var isPKMode: Bool {
        match.currentPeriodLabel(at: currentTime)?.lowercased() == "pk"
    }

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

            if isPKMode {
                PKStateView(match: match, currentTime: currentTime)
                    .padding(.horizontal)

                HStack(spacing: 12) {
                    PKTeamButtons(teamName: match.homeTeamName, color: .blue) { isGoal in
                        onPKKick(.home, isGoal)
                    }

                    Button {
                        onPKUndo()
                    } label: {
                        Label("取消", systemImage: "arrow.uturn.backward")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .disabled(match.pkKicks.isEmpty)

                    PKTeamButtons(teamName: match.awayTeamName, color: .red) { isGoal in
                        onPKKick(.away, isGoal)
                    }
                }
                .padding(.horizontal)
            } else {
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
            }

            // Penalty timers
            if match.scoreboardStyle.showPenaltyTimer {
                PenaltyTimerSection(
                    match: match,
                    currentTime: currentTime,
                    onAdd: onAddPenaltyTimer,
                    onRemove: onRemovePenaltyTimer
                )
            }

            // Timeouts
            if match.scoreboardStyle.showTimeouts {
                TimeoutSection(
                    match: match,
                    currentTime: currentTime,
                    onStart: onStartTimeout,
                    onEnd: onEndTimeout,
                    onRemove: onRemoveTimeout
                )
            }

            // セグメント追加ボタン
            HStack(spacing: 8) {
                Button {
                    onAddSegment()
                } label: {
                    Label("セグメント追加", systemImage: "plus.circle")
                        .font(.caption2.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .tint(.blue)

                if match.timerSegments.contains(where: { $0.timerStartTime != nil }) {
                    Button {
                        onAddSegmentWithRestart()
                    } label: {
                        Label("タイマー引き継ぎ", systemImage: "arrow.clockwise.circle")
                            .font(.caption2.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                }
            }
            .padding(.horizontal)

            // Segment list (newest first)
            ForEach(Array(match.timerSegments.enumerated()).reversed(), id: \.offset) { index, segment in
                SegmentControlRow(
                    index: index,
                    segment: segment,
                    onSegmentStart: { onSegmentStart(index) },
                    onTimerStart: { onSegmentTimerStart(index) },
                    onTimerStop: { onSegmentTimerStop(index) },
                    onTimerClear: { onSegmentTimerClear(index) },
                    onOffsetChange: { onSegmentOffsetChange(index, $0) },
                    onPeriodLabel: { onSegmentPeriodLabel(index, $0) },
                    onShowPlusPrefix: { onSegmentShowPlusPrefix(index, $0) },
                    onTimerColor: { onSegmentTimerColor(index, $0) },
                    onRemove: match.timerSegments.count > 1 ? { onRemoveSegment(index) } : nil,
                    showTimerOptions: match.scoreboardStyle.showTimerOptions
                )
            }
        }
    }
}

// MARK: - Segment Control Row

private struct SegmentControlRow: View {
    let index: Int
    let segment: TimerSegment
    let onSegmentStart: () -> Void
    let onTimerStart: () -> Void
    let onTimerStop: () -> Void
    let onTimerClear: () -> Void
    let onOffsetChange: (TimeInterval) -> Void
    let onPeriodLabel: (String?) -> Void
    let onShowPlusPrefix: (Bool) -> Void
    let onTimerColor: (String?) -> Void
    let onRemove: (() -> Void)?
    var showTimerOptions: Bool = false

    static func hexString(from uiColor: UIColor) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: nil)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }

    private var currentTimerColor: Color {
        guard let hex = segment.timerColorHex else { return .white }
        return Color(uiColor: UIColor(hex: hex) ?? .white)
    }

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

            // ピリオドラベル
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(ScoreControlsView.periodPresets, id: \.self) { preset in
                        Button(preset) {
                            onPeriodLabel(segment.periodLabel == preset ? nil : preset)
                        }
                        .buttonStyle(.bordered)
                        .tint(segment.periodLabel == preset ? .accentColor : .secondary)
                        .controlSize(.small)
                    }

                    TextField("ラベル", text: Binding(
                        get: {
                            let current = segment.periodLabel ?? ""
                            return ScoreControlsView.periodPresets.contains(current) ? "" : current
                        },
                        set: { newValue in
                            onPeriodLabel(newValue.isEmpty ? nil : newValue)
                        }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                    .frame(width: 80)
                }
            }

            // タイマー操作行
            HStack(spacing: 8) {
                Button {
                    onSegmentStart()
                } label: {
                    VStack(spacing: 2) {
                        Label("区切り開始", systemImage: "flag.circle")
                            .font(.caption2.weight(.semibold))
                        if let segStart = segment.segmentStartTime {
                            Text(TimeFormatting.format(seconds: segStart))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .tint(.purple)

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
                .disabled(segment.timerStartTime == nil && segment.segmentStartTime == nil)

                if segment.segmentStartTime != nil || segment.timerStartTime != nil || segment.timerStopTime != nil {
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

                // タイマー表示オプション（+表示 / 色）
                if showTimerOptions {
                HStack(spacing: 8) {
                    Toggle(isOn: Binding(
                        get: { segment.showPlusPrefix },
                        set: { onShowPlusPrefix($0) }
                    )) {
                        Text("+表示")
                            .font(.caption2)
                    }
                    .toggleStyle(.button)
                    .controlSize(.small)
                    .tint(.orange)

                    Spacer()

                    Text("タイマー色")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    ColorPicker(
                        "",
                        selection: Binding(
                            get: { currentTimerColor },
                            set: { newColor in
                                let uiColor = UIColor(newColor)
                                onTimerColor(SegmentControlRow.hexString(from: uiColor))
                            }
                        ),
                        supportsOpacity: false
                    )
                    .labelsHidden()
                    .frame(width: 28, height: 28)

                    if segment.timerColorHex != nil {
                        Button {
                            onTimerColor(nil)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                } // showTimerOptions
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

// MARK: - PK State Display

private struct PKStateView: View {
    let match: Match
    let currentTime: TimeInterval

    var body: some View {
        let visibleKicks = match.pkKicksAt(time: currentTime)
        let homeKicks = visibleKicks.filter { $0.team == .home }.sorted { $0.order < $1.order }
        let awayKicks = visibleKicks.filter { $0.team == .away }.sorted { $0.order < $1.order }
        let homeGoals = homeKicks.filter(\.isGoal).count
        let awayGoals = awayKicks.filter(\.isGoal).count

        VStack(spacing: 4) {
            Text("PK \(homeGoals) - \(awayGoals)")
                .font(.caption.weight(.bold))
                .monospacedDigit()

            VStack(alignment: .leading, spacing: 2) {
                PKMarkRow(teamName: match.homeTeamName, kicks: homeKicks)
                PKMarkRow(teamName: match.awayTeamName, kicks: awayKicks)
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))
    }
}

private struct PKMarkRow: View {
    let teamName: String
    let kicks: [PKKick]

    var body: some View {
        HStack(spacing: 4) {
            Text(teamName)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .frame(width: 60, alignment: .leading)
            ForEach(kicks) { kick in
                Text(kick.isGoal ? "◯" : "✗")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(kick.isGoal ? .green : .red)
                    .frame(width: 18)
            }
        }
    }
}

// MARK: - PK Team Buttons

private struct PKTeamButtons: View {
    let teamName: String
    let color: Color
    let onKick: (Bool) -> Void
    @State private var tapCount = 0

    var body: some View {
        VStack(spacing: 4) {
            Text(teamName)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
            HStack(spacing: 6) {
                Button {
                    tapCount += 1
                    onKick(true)
                } label: {
                    Text("◯")
                        .font(.title3.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)

                Button {
                    tapCount += 1
                    onKick(false)
                } label: {
                    Text("✗")
                        .font(.title3.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
        .sensoryFeedback(.impact(weight: .heavy), trigger: tapCount)
    }
}

// MARK: - Goal Button

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

// MARK: - Penalty Timer Section

// MARK: - Timeout Section

private struct TimeoutSection: View {
    let match: Match
    let currentTime: TimeInterval
    let onStart: (Team) -> Void
    let onEnd: (UUID, TimeInterval) -> Void
    let onRemove: (UUID) -> Void

    private var activeTimeout: TimeoutEvent? {
        match.timeouts.first { $0.isActive(at: currentTime) }
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text("タイムアウト")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                Spacer()
                let homeCount = match.timeoutCount(for: .home, at: currentTime)
                let awayCount = match.timeoutCount(for: .away, at: currentTime)
                Text("\(match.homeTeamName): \(homeCount)  \(match.awayTeamName): \(awayCount)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // アクティブなタイムアウト表示
            if let active = activeTimeout {
                HStack(spacing: 6) {
                    Image(systemName: "pause.circle.fill")
                        .font(.title3)
                        .foregroundStyle(active.team == .home ? .blue : .red)
                    Text(active.team == .home ? match.homeTeamName : match.awayTeamName)
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1)
                    Spacer()
                    if let elapsed = active.elapsedSeconds(at: currentTime) {
                        Text(TimeFormatting.format(seconds: elapsed))
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(.orange)
                    }
                }

                // タイムアウト終了ボタン
                Button {
                    onEnd(active.id, currentTime)
                } label: {
                    Label("タイムアウト終了", systemImage: "play.circle.fill")
                        .font(.caption2.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)

                // 削除ボタン
                Button {
                    onRemove(active.id)
                } label: {
                    Label("取消", systemImage: "xmark.circle")
                        .font(.caption2)
                }
                .buttonStyle(.bordered)
                .tint(.secondary)
            } else {
                // タイムアウト開始ボタン
                HStack(spacing: 12) {
                    Button {
                        onStart(.home)
                    } label: {
                        Label(match.homeTeamName, systemImage: "pause.circle")
                            .font(.caption2.weight(.medium))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)

                    Button {
                        onStart(.away)
                    } label: {
                        Label(match.awayTeamName, systemImage: "pause.circle")
                            .font(.caption2.weight(.medium))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
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

private struct PenaltyTimerSection: View {
    let match: Match
    let currentTime: TimeInterval
    let onAdd: (Team, TimeInterval) -> Void
    let onRemove: (UUID) -> Void
    @State private var showingCustomSheet: Team? = nil

    static let presets: [(label: String, seconds: TimeInterval)] = [
        ("2分", 120),
        ("5分", 300),
    ]

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text("ペナルティタイマー")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            // アクティブなタイマー表示
            let homeActive = match.activePenaltyTimers(at: currentTime, for: .home)
            let awayActive = match.activePenaltyTimers(at: currentTime, for: .away)

            if !homeActive.isEmpty || !awayActive.isEmpty {
                VStack(spacing: 4) {
                    ForEach(homeActive) { timer in
                        penaltyRow(timer: timer, teamName: match.homeTeamName, color: .blue)
                    }
                    ForEach(awayActive) { timer in
                        penaltyRow(timer: timer, teamName: match.awayTeamName, color: .red)
                    }
                }
            }

            // 追加ボタン
            HStack(spacing: 8) {
                penaltyAddButtons(teamName: match.homeTeamName, team: .home, color: .blue)
                Spacer()
                penaltyAddButtons(teamName: match.awayTeamName, team: .away, color: .red)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary)
        )
        .padding(.horizontal)
        .sheet(item: $showingCustomSheet) { team in
            PenaltyDurationSheet(
                team: team,
                teamName: team == .home ? match.homeTeamName : match.awayTeamName,
                onAdd: onAdd
            )
            .presentationDetents([.height(280)])
        }
    }

    private func penaltyRow(timer: PenaltyTimer, teamName: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "timer")
                .font(.caption)
                .foregroundStyle(color)
            Text(teamName)
                .font(.caption2)
                .lineLimit(1)
            Spacer()
            if let remaining = timer.remainingSeconds(at: currentTime) {
                Text(TimeFormatting.format(seconds: remaining))
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.yellow)
            }
            Button {
                onRemove(timer.id)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }

    private func penaltyAddButtons(teamName: String, team: Team, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(teamName)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
            HStack(spacing: 4) {
                ForEach(Self.presets, id: \.seconds) { preset in
                    Button {
                        onAdd(team, preset.seconds)
                    } label: {
                        Text(preset.label)
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.bordered)
                    .tint(color)
                    .controlSize(.mini)
                }
                Button {
                    showingCustomSheet = team
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.caption)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.bordered)
                .tint(color)
                .controlSize(.mini)
            }
        }
    }
}

// MARK: - Custom Penalty Duration Sheet

private struct PenaltyDurationSheet: View {
    let team: Team
    let teamName: String
    let onAdd: (Team, TimeInterval) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var minutes: Int = 2
    @State private var seconds: Int = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text(String(format: "%d:%02d", minutes, seconds))
                    .font(.system(.largeTitle, design: .monospaced, weight: .semibold))
                    .monospacedDigit()
                    .padding(.top, 8)

                HStack(spacing: 40) {
                    VStack(spacing: 6) {
                        Button { minutes += 1 } label: {
                            Image(systemName: "plus.circle.fill").font(.title2)
                        }
                        Text("\(minutes)")
                            .font(.title3.weight(.medium))
                            .monospacedDigit()
                            .frame(minWidth: 40)
                        Button { minutes = max(0, minutes - 1) } label: {
                            Image(systemName: "minus.circle.fill").font(.title2)
                        }
                        .disabled(minutes <= 0 && seconds <= 0)
                        Text("分").font(.caption).foregroundStyle(.secondary)
                    }

                    Text(":").font(.title).foregroundStyle(.secondary)

                    VStack(spacing: 6) {
                        Button {
                            seconds += 10
                            if seconds >= 60 { minutes += 1; seconds -= 60 }
                        } label: {
                            Image(systemName: "plus.circle.fill").font(.title2)
                        }
                        Text(String(format: "%02d", seconds))
                            .font(.title3.weight(.medium))
                            .monospacedDigit()
                            .frame(minWidth: 40)
                        Button {
                            seconds -= 10
                            if seconds < 0 { minutes = max(0, minutes - 1); seconds += 60 }
                            if minutes <= 0 && seconds < 0 { seconds = 0 }
                        } label: {
                            Image(systemName: "minus.circle.fill").font(.title2)
                        }
                        .disabled(minutes <= 0 && seconds <= 0)
                        Text("秒").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.borderless)
            }
            .padding()
            .navigationTitle("ペナルティ時間")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        let total = TimeInterval(minutes * 60 + seconds)
                        if total > 0 { onAdd(team, total) }
                        dismiss()
                    }
                    .disabled(minutes == 0 && seconds == 0)
                }
            }
        }
    }
}

// MARK: - UIColor hex helper

private extension UIColor {
    convenience init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s = String(s.dropFirst()) }
        guard s.count == 6, let value = UInt64(s, radix: 16) else { return nil }
        self.init(
            red:   CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8)  & 0xFF) / 255,
            blue:  CGFloat(value         & 0xFF) / 255,
            alpha: 1
        )
    }
}
