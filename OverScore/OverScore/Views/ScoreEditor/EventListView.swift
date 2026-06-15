import SwiftUI

struct EventListView: View {
    let events: [ScoreEvent]
    var pkKicks: [PKKick] = []
    var penaltyTimers: [PenaltyTimer] = []
    let homeTeamName: String
    let awayTeamName: String
    var onDeleteGoal: ((UUID) -> Void)? = nil
    var onEditGoalTimestamp: ((UUID, TimeInterval) -> Void)? = nil
    var onDeletePKKick: ((UUID) -> Void)? = nil
    var onEditPKKickTimestamp: ((UUID, TimeInterval) -> Void)? = nil
    var onDeletePenaltyTimer: ((UUID) -> Void)? = nil
    var onEditPenaltyTimerTimestamp: ((UUID, TimeInterval) -> Void)? = nil
    var timeouts: [TimeoutEvent] = []
    var onDeleteTimeout: ((UUID) -> Void)? = nil
    var onEditTimeoutTimestamp: ((UUID, TimeInterval) -> Void)? = nil

    @State private var editingItem: EventItem? = nil
    @State private var confirmingDeleteItem: EventItem? = nil

    private var canEdit: Bool { onDeleteGoal != nil || onDeletePKKick != nil }

    var body: some View {
        if allItems.isEmpty {
            ContentUnavailableView(
                "まだ得点がありません",
                systemImage: "soccerball",
                description: Text("ゴールボタンで得点を記録しましょう")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            LazyVStack(spacing: 0) {
                ForEach(allItems) { item in
                    eventRow(item: item)
                    Divider()
                        .padding(.leading, 16)
                }
            }
            .sheet(item: $editingItem) { item in
                TimeEditSheet(initialTime: item.timestamp) { newTime in
                    switch item.kind {
                    case .goal: onEditGoalTimestamp?(item.sourceID, newTime)
                    case .pkKick: onEditPKKickTimestamp?(item.sourceID, newTime)
                    case .penaltyTimer: onEditPenaltyTimerTimestamp?(item.sourceID, newTime)
                    case .timeout: onEditTimeoutTimestamp?(item.sourceID, newTime)
                    }
                }
                .presentationDetents([.height(240)])
            }
            .confirmationDialog(
                "このイベントを削除しますか？",
                isPresented: Binding(
                    get: { confirmingDeleteItem != nil },
                    set: { if !$0 { confirmingDeleteItem = nil } }
                ),
                titleVisibility: .visible
            ) {
                if let item = confirmingDeleteItem {
                    Button("削除", role: .destructive) {
                        switch item.kind {
                        case .goal: onDeleteGoal?(item.sourceID)
                        case .pkKick: onDeletePKKick?(item.sourceID)
                        case .penaltyTimer: onDeletePenaltyTimer?(item.sourceID)
                        case .timeout: onDeleteTimeout?(item.sourceID)
                        }
                        confirmingDeleteItem = nil
                    }
                }
                Button("キャンセル", role: .cancel) {
                    confirmingDeleteItem = nil
                }
            }
        }
    }

    @ViewBuilder
    private func eventRow(item: EventItem) -> some View {
        HStack(spacing: 0) {
            // 時刻（タップで時刻編集）
            Button {
                editingItem = item
            } label: {
                Text(TimeFormatting.format(seconds: item.timestamp))
                    .monospacedDigit()
                    .font(.subheadline)
                    .foregroundStyle(canEdit ? .blue : .secondary)
                    .frame(width: 50, alignment: .leading)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
            .disabled(!canEdit)

            // イベント内容
            HStack {
                switch item.kind {
                case .goal(let team):
                    Image(systemName: "soccerball")
                        .foregroundStyle(team == .home ? .blue : .red)
                    Text(team == .home ? homeTeamName : awayTeamName)
                        .font(.subheadline)
                    Spacer()
                    Text("\(item.homeScore) - \(item.awayScore)")
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()

                case .pkKick(let team, let isGoal):
                    Image(systemName: "p.circle")
                        .foregroundStyle(team == .home ? .blue : .red)
                    Text(team == .home ? homeTeamName : awayTeamName)
                        .font(.subheadline)
                    Text(isGoal ? "◯" : "✗")
                        .font(.subheadline)
                        .foregroundStyle(isGoal ? .green : .secondary)
                    Spacer()
                    Text("\(item.homeScore) - \(item.awayScore) PK")
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()

                case .penaltyTimer(let team, let durationSeconds):
                    Image(systemName: "timer")
                        .foregroundStyle(team == .home ? .blue : .red)
                    Text(team == .home ? homeTeamName : awayTeamName)
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int(durationSeconds) / 60)分")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.orange)

                case .timeout(let team):
                    Image(systemName: "pause.circle.fill")
                        .foregroundStyle(team == .home ? .blue : .red)
                    Text(team == .home ? homeTeamName : awayTeamName)
                        .font(.subheadline)
                    Spacer()
                    Text("タイムアウト")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }
            .padding(.vertical, 14)
            .padding(.leading, 4)

            // 削除ボタン
            if canEdit {
                Button {
                    confirmingDeleteItem = item
                } label: {
                    Image(systemName: "trash")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, 16)
    }

    private var allItems: [EventItem] {
        var result: [EventItem] = []

        // 通常ゴール
        let sortedGoals = events.sorted { $0.timestamp < $1.timestamp }
        var home = 0
        var away = 0
        for event in sortedGoals {
            switch event.team {
            case .home: home += 1
            case .away: away += 1
            }
            result.append(EventItem(
                id: event.id.uuidString,
                sourceID: event.id,
                timestamp: event.timestamp,
                kind: .goal(team: event.team),
                homeScore: home,
                awayScore: away
            ))
        }

        // PKキック
        let sortedPK = pkKicks.sorted { $0.timestamp < $1.timestamp }
        var pkHome = 0
        var pkAway = 0
        for kick in sortedPK {
            if kick.isGoal {
                switch kick.team {
                case .home: pkHome += 1
                case .away: pkAway += 1
                }
            }
            result.append(EventItem(
                id: kick.id.uuidString,
                sourceID: kick.id,
                timestamp: kick.timestamp,
                kind: .pkKick(team: kick.team, isGoal: kick.isGoal),
                homeScore: pkHome,
                awayScore: pkAway
            ))
        }

        // ペナルティタイマー
        for timer in penaltyTimers {
            result.append(EventItem(
                id: timer.id.uuidString,
                sourceID: timer.id,
                timestamp: timer.timestamp,
                kind: .penaltyTimer(team: timer.team, durationSeconds: timer.durationSeconds),
                homeScore: 0,
                awayScore: 0
            ))
        }

        // タイムアウト
        for timeout in timeouts {
            result.append(EventItem(
                id: timeout.id.uuidString,
                sourceID: timeout.id,
                timestamp: timeout.timestamp,
                kind: .timeout(team: timeout.team),
                homeScore: 0,
                awayScore: 0
            ))
        }

        return result.sorted { $0.timestamp < $1.timestamp }
    }
}

// MARK: - Time Edit Sheet

private struct TimeEditSheet: View {
    let initialTime: TimeInterval
    let onSave: (TimeInterval) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var totalSeconds: Int

    init(initialTime: TimeInterval, onSave: @escaping (TimeInterval) -> Void) {
        self.initialTime = initialTime
        self.onSave = onSave
        self._totalSeconds = State(initialValue: max(0, Int(initialTime)))
    }

    private var minutes: Int { totalSeconds / 60 }
    private var seconds: Int { totalSeconds % 60 }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text(String(format: "%d:%02d", minutes, seconds))
                    .font(.system(.largeTitle, design: .monospaced, weight: .semibold))
                    .monospacedDigit()
                    .padding(.top, 8)

                HStack(spacing: 40) {
                    // 分
                    VStack(spacing: 6) {
                        Button { totalSeconds += 60 } label: {
                            Image(systemName: "plus.circle.fill").font(.title2)
                        }
                        Text(String(format: "%d", minutes))
                            .font(.title3.weight(.medium))
                            .monospacedDigit()
                            .frame(minWidth: 40)
                        Button { totalSeconds = max(0, totalSeconds - 60) } label: {
                            Image(systemName: "minus.circle.fill").font(.title2)
                        }
                        .disabled(minutes <= 0)
                        Text("分").font(.caption).foregroundStyle(.secondary)
                    }

                    Text(":").font(.title).foregroundStyle(.secondary)

                    // 秒
                    VStack(spacing: 6) {
                        Button { totalSeconds += 1 } label: {
                            Image(systemName: "plus.circle.fill").font(.title2)
                        }
                        Text(String(format: "%02d", seconds))
                            .font(.title3.weight(.medium))
                            .monospacedDigit()
                            .frame(minWidth: 40)
                        Button { totalSeconds = max(0, totalSeconds - 1) } label: {
                            Image(systemName: "minus.circle.fill").font(.title2)
                        }
                        .disabled(totalSeconds <= 0)
                        Text("秒").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.borderless)
            }
            .padding()
            .navigationTitle("時刻を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(TimeInterval(totalSeconds))
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Types

private enum EventKind {
    case goal(team: Team)
    case pkKick(team: Team, isGoal: Bool)
    case penaltyTimer(team: Team, durationSeconds: TimeInterval)
    case timeout(team: Team)
}

private struct EventItem: Identifiable {
    let id: String
    let sourceID: UUID
    let timestamp: TimeInterval
    let kind: EventKind
    let homeScore: Int
    let awayScore: Int
}
