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
        .onAppear { setupPlayer() }
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

            ScoreControlsView(
                match: match,
                currentTime: playerVM.currentTime,
                onGoal: { team in addGoal(team: team, at: playerVM.currentTime) },
                onUndo: { undoLastGoal() },
                onTimerStart: { setTimerStart(at: playerVM.currentTime) },
                onTimerStop: { setTimerStop(at: playerVM.currentTime) },
                onTimerClear: { clearTimer() },
                onTimerOffsetChange: { seconds in setTimerOffset(seconds: seconds) }
            )
            .padding(.vertical, 6)

            Divider()

            EventListView(
                events: match.scoreEvents,
                homeTeamName: match.homeTeamName,
                awayTeamName: match.awayTeamName
            )
            .frame(maxHeight: .infinity)
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
            VStack(spacing: 0) {
                ScoreControlsView(
                    match: match,
                    currentTime: playerVM.currentTime,
                    onGoal: { team in addGoal(team: team, at: playerVM.currentTime) },
                    onUndo: { undoLastGoal() },
                    onTimerStart: { setTimerStart(at: playerVM.currentTime) },
                    onTimerStop: { setTimerStop(at: playerVM.currentTime) },
                    onTimerClear: { clearTimer() },
                    onTimerOffsetChange: { seconds in setTimerOffset(seconds: seconds) }
                )
                .padding(.vertical, 12)

                Divider()

                EventListView(
                    events: match.scoreEvents,
                    homeTeamName: match.homeTeamName,
                    awayTeamName: match.awayTeamName
                )
                .frame(maxHeight: .infinity)
            }
            .frame(width: 320)
        }
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

    private func setTimerStart(at timestamp: TimeInterval) {
        match.timerStartTime = timestamp
        // stop が start 以下なら stop をクリア
        if let stop = match.timerStopTime, stop <= timestamp {
            match.timerStopTime = nil
        }
    }

    private func setTimerStop(at timestamp: TimeInterval) {
        guard let start = match.timerStartTime, timestamp > start else { return }
        match.timerStopTime = timestamp
    }

    private func clearTimer() {
        match.timerStartTime = nil
        match.timerStopTime = nil
        match.timerStartOffset = nil
    }

    private func setTimerOffset(seconds: TimeInterval) {
        let clamped = max(0, seconds)
        match.timerStartOffset = clamped > 0 ? clamped : nil
    }
}
