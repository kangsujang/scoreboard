import SwiftUI
import SwiftData

struct ScoreEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(Router.self) private var router
    @Bindable var match: Match
    @State private var playerVM: PlayerViewModel?

    var body: some View {
        VStack(spacing: 0) {
            if let playerVM {
                VideoPlayerView(player: playerVM.player)
                    .aspectRatio(16/9, contentMode: .fit)
                    .background(.black)

                PlaybackControlsView(playerVM: playerVM)
                    .padding(.vertical, 8)

                Divider()

                ScoreControlsView(
                    match: match,
                    currentTime: playerVM.currentTime,
                    onGoal: { team in
                        addGoal(team: team, at: playerVM.currentTime)
                    },
                    onUndo: {
                        undoLastGoal()
                    }
                )
                .padding(.vertical, 8)

                Divider()

                EventListView(
                    events: match.scoreEvents,
                    homeTeamName: match.homeTeamName,
                    awayTeamName: match.awayTeamName
                )
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
        }
        .onDisappear {
            playerVM?.pause()
        }
    }

    private func setupPlayer() {
        guard let url = match.videoURL else { return }
        playerVM = PlayerViewModel(url: url)
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
}
