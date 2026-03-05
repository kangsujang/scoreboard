import SwiftUI
import SwiftData

struct ScoreEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(Router.self) private var router
    @Bindable var match: Match
    @State private var playerVM: PlayerViewModel?
    @State private var videoAspectRatio: CGFloat = 16.0 / 9.0

    var body: some View {
        Group {
            if let playerVM {
                if horizontalSizeClass == .regular {
                    iPadLayout(playerVM: playerVM)
                } else {
                    iPhoneLayout(playerVM: playerVM)
                }
            } else {
                ContentUnavailableView(
                    "動画が見つかりません",
                    systemImage: "video.slash",
                    description: Text("試合に動画が設定されていません")
                )
            }
        }
        .navigationTitle("スコア記録")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("完了") {
                    playerVM?.pause()
                    router.navigate(to: .matchDetail(match))
                }
            }
        }
        .onAppear {
            setupPlayer()
            ensureAtLeastOneSegment()
        }
        .onDisappear { playerVM?.pause() }
    }

    // MARK: - iPhone Layout (縦積み・画面全体利用)

    private func iPhoneLayout(playerVM: PlayerViewModel) -> some View {
        VStack(spacing: 0) {
            VideoPlayerView(player: playerVM.player)
                .aspectRatio(videoAspectRatio, contentMode: .fit)
                .background(.black)
                .clipped()

            PlaybackControlsView(playerVM: playerVM)
                .padding(.vertical, 6)

            ScrollView {
                scoreControls(playerVM: playerVM)
                    .padding(.vertical, 6)

                Divider()

                EventListView(
                    events: match.scoreEvents,
                    homeTeamName: match.homeTeamName,
                    awayTeamName: match.awayTeamName
                )
            }
        }
        .ignoresSafeArea(.container, edges: .bottom)
    }

    // MARK: - iPad Layout (横並び)

    private func iPadLayout(playerVM: PlayerViewModel) -> some View {
        HStack(spacing: 0) {
            // 左: 動画 + 再生コントロール
            VStack(spacing: 0) {
                VideoPlayerView(player: playerVM.player)
                    .background(.black)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                PlaybackControlsView(playerVM: playerVM)
                    .padding(.vertical, 8)
                    .padding(.horizontal)
            }
            .frame(maxWidth: .infinity)

            Divider()

            // 右: スコアコントロール + イベントリスト
            ScrollView {
                VStack(spacing: 0) {
                    scoreControls(playerVM: playerVM)
                        .padding(.vertical, 12)

                    Divider()

                    EventListView(
                        events: match.scoreEvents,
                        homeTeamName: match.homeTeamName,
                        awayTeamName: match.awayTeamName
                    )
                }
            }
            .frame(width: 320)
        }
    }

    private func scoreControls(playerVM: PlayerViewModel) -> some View {
        ScoreControlsView(
            match: match,
            currentTime: playerVM.currentTime,
            onGoal: { team in addGoal(team: team, at: playerVM.currentTime) },
            onUndo: { undoLastGoal() },
            onSegmentStart: { idx in setSegmentStart(at: idx, time: playerVM.currentTime) },
            onSegmentTimerStart: { idx in setSegmentTimerStart(at: idx, time: playerVM.currentTime) },
            onSegmentTimerStop: { idx in setSegmentTimerStop(at: idx, time: playerVM.currentTime) },
            onSegmentTimerClear: { idx in clearSegmentTimer(at: idx) },
            onSegmentOffsetChange: { idx, secs in setSegmentOffset(at: idx, seconds: secs) },
            onSegmentPeriodLabel: { idx, label in setSegmentPeriodLabel(at: idx, label: label) },
            onAddSegment: { addTimerSegment() },
            onRemoveSegment: { idx in removeTimerSegment(at: idx) }
        )
    }

    // MARK: - Actions

    private func setupPlayer() {
        let urls = match.videoURLs
        guard !urls.isEmpty else { return }
        Task {
            if let url = urls.first, let size = await ThumbnailGenerator.videoSize(for: url) {
                videoAspectRatio = size.width / size.height
            }
            do {
                playerVM = try await PlayerViewModel.create(urls: urls)
            } catch {
                // プレイヤー作成失敗時は nil のまま（ContentUnavailableView を表示）
            }
        }
    }

    private func ensureAtLeastOneSegment() {
        if match.timerSegments.isEmpty {
            match.timerSegments = [TimerSegment()]
        }
    }

    private func addGoal(team: Team, at timestamp: TimeInterval) {
        let event = ScoreEvent(team: team, timestamp: timestamp)
        event.match = match
        match.scoreEvents.append(event)
        modelContext.insert(event)
    }

    private func undoLastGoal() {
        guard let lastEvent = match.scoreEvents.sorted(by: { $0.createdAt < $1.createdAt }).last else {
            return
        }
        match.scoreEvents.removeAll { $0.id == lastEvent.id }
        modelContext.delete(lastEvent)
    }

    // MARK: - Segment Actions

    private func setSegmentStart(at index: Int, time: TimeInterval) {
        var segments = match.timerSegments
        guard index < segments.count else { return }
        segments[index].segmentStartTime = time
        // キックオフが区切り開始より前ならクリア
        if let kickoff = segments[index].timerStartTime, kickoff < time {
            segments[index].timerStartTime = nil
        }
        match.timerSegments = segments
    }

    private func setSegmentTimerStart(at index: Int, time: TimeInterval) {
        var segments = match.timerSegments
        guard index < segments.count else { return }
        segments[index].timerStartTime = time
        if let stop = segments[index].timerStopTime, stop <= time {
            segments[index].timerStopTime = nil
        }
        match.timerSegments = segments
    }

    private func setSegmentTimerStop(at index: Int, time: TimeInterval) {
        var segments = match.timerSegments
        guard index < segments.count else { return }
        guard let start = segments[index].timerStartTime, time > start else { return }
        segments[index].timerStopTime = time
        match.timerSegments = segments
    }

    private func clearSegmentTimer(at index: Int) {
        var segments = match.timerSegments
        guard index < segments.count else { return }
        segments[index].segmentStartTime = nil
        segments[index].timerStartTime = nil
        segments[index].timerStopTime = nil
        segments[index].timerStartOffset = nil
        match.timerSegments = segments
    }

    private func setSegmentOffset(at index: Int, seconds: TimeInterval) {
        var segments = match.timerSegments
        guard index < segments.count else { return }
        let clamped = max(0, seconds)
        segments[index].timerStartOffset = clamped > 0 ? clamped : nil
        match.timerSegments = segments
    }

    private func setSegmentPeriodLabel(at index: Int, label: String?) {
        var segments = match.timerSegments
        guard index < segments.count else { return }
        segments[index].periodLabel = label
        match.timerSegments = segments
    }

    private func addTimerSegment() {
        var segments = match.timerSegments
        segments.append(TimerSegment())
        match.timerSegments = segments
    }

    private func removeTimerSegment(at index: Int) {
        var segments = match.timerSegments
        guard segments.count > 1, index < segments.count else { return }
        segments.remove(at: index)
        match.timerSegments = segments
    }
}
