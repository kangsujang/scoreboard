import SwiftUI

struct MatchDetailView: View {
    @Environment(Router.self) private var router
    @Bindable var match: Match
    @State private var showStyleSheet = false
    @State private var thumbnail: UIImage?
    @State private var videoAspectRatio: CGFloat = 16.0 / 9.0

    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    ScoreboardPreviewView(
                        homeTeamName: match.homeTeamName,
                        awayTeamName: match.awayTeamName,
                        homeScore: match.homeScore,
                        awayScore: match.awayScore,
                        style: match.scoreboardStyle,
                        currentPeriodLabel: match.timerSegments.first?.periodLabel,
                        thumbnail: thumbnail,
                        videoAspectRatio: videoAspectRatio
                    )

                    HStack {
                        VStack {
                            Text(match.homeTeamName)
                                .font(.headline)
                            Text("\(match.homeScore)")
                                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)

                        Text("-")
                            .font(.title2)
                            .foregroundStyle(.secondary)

                        VStack {
                            Text(match.awayTeamName)
                                .font(.headline)
                            Text("\(match.awayScore)")
                                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                    }

                    Text(match.createdAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            Section("スコアイベント (\(match.scoreEvents.count))") {
                if match.scoreEvents.isEmpty {
                    Text("得点記録がありません")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(eventsWithScore, id: \.event.id) { item in
                        HStack {
                            Text(TimeFormatting.format(seconds: item.event.timestamp))
                                .monospacedDigit()
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(width: 50, alignment: .leading)

                            Image(systemName: "soccerball")
                                .foregroundStyle(item.event.team == .home ? .blue : .red)

                            Text(item.event.team == .home ? match.homeTeamName : match.awayTeamName)
                                .font(.subheadline)

                            Spacer()

                            Text("\(item.homeScore) - \(item.awayScore)")
                                .font(.subheadline.weight(.semibold))
                                .monospacedDigit()
                        }
                    }
                }
            }

            Section("アクション") {
                Button {
                    router.navigate(to: .scoreEditor(match))
                } label: {
                    Label("スコア編集", systemImage: "pencil")
                }

                Button {
                    showStyleSheet = true
                } label: {
                    Label("スコアボード設定", systemImage: "paintbrush")
                }

                Button {
                    router.navigate(to: .export(match))
                } label: {
                    Label("エクスポート", systemImage: "square.and.arrow.up")
                }
                .disabled(match.videoURLs.isEmpty)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("試合詳細")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showStyleSheet) {
            ScoreboardStyleSheet(match: match, thumbnail: thumbnail, videoAspectRatio: videoAspectRatio)
        }
        .task(id: match.videoBookmarksData ?? match.videoBookmark) {
            guard let url = match.videoURLs.first else {
                thumbnail = nil
                return
            }
            thumbnail = await ThumbnailGenerator.generate(for: url)
            if let size = await ThumbnailGenerator.videoSize(for: url) {
                videoAspectRatio = size.width / size.height
            }
        }
    }

    private var eventsWithScore: [EventWithScoreItem] {
        let sorted = match.sortedEvents
        var home = 0
        var away = 0
        return sorted.map { event in
            switch event.team {
            case .home: home += 1
            case .away: away += 1
            }
            return EventWithScoreItem(event: event, homeScore: home, awayScore: away)
        }
    }
}

private struct EventWithScoreItem {
    let event: ScoreEvent
    let homeScore: Int
    let awayScore: Int
}
