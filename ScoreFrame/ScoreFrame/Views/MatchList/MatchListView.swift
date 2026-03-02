import SwiftUI
import SwiftData

struct MatchListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(Router.self) private var router
    @Query(sort: \Match.createdAt, order: .reverse) private var matches: [Match]
    @State private var showDeleteConfirmation = false
    @State private var matchToDelete: Match?

    var body: some View {
        Group {
            if matches.isEmpty {
                emptyStateView
            } else {
                matchList
            }
        }
        .navigationTitle("ScoreFrame")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    router.navigate(to: .matchSetup)
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("試合を削除", isPresented: $showDeleteConfirmation) {
            Button("削除", role: .destructive) {
                if let match = matchToDelete {
                    deleteMatch(match)
                }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("この試合データを削除しますか？元に戻すことはできません。")
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("試合がありません", systemImage: "sportscourt")
        } description: {
            Text("右上の＋ボタンから試合を作成しましょう")
        } actions: {
            Button("試合を作成") {
                router.navigate(to: .matchSetup)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var matchList: some View {
        List {
            ForEach(matches) { match in
                Button {
                    router.navigate(to: .matchDetail(match))
                } label: {
                    MatchRowView(match: match)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        matchToDelete = match
                        showDeleteConfirmation = true
                    } label: {
                        Label("削除", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private func deleteMatch(_ match: Match) {
        if let url = match.videoURL {
            VideoImportService.deleteVideo(at: url)
        }
        modelContext.delete(match)
        matchToDelete = nil
    }
}
