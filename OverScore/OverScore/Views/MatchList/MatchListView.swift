import SwiftUI
import SwiftData

struct MatchListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(Router.self) private var router
    @Query(sort: \Match.createdAt, order: .reverse) private var matches: [Match]
    @State private var showDeleteConfirmation = false
    @State private var matchToDelete: Match?
    @State private var showSettings = false

    var body: some View {
        Group {
            if matches.isEmpty {
                emptyStateView
            } else {
                matchList
            }
        }
        .navigationTitle("OverScore")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    router.navigate(to: .sportSelect)
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
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
        VStack(spacing: 0) {
            ContentUnavailableView {
                Label("試合がありません", systemImage: "sportscourt")
            } description: {
                Text("下のボタンから試合を作成しましょう")
            }
            .frame(maxHeight: .infinity)

            Button {
                router.navigate(to: .sportSelect)
            } label: {
                Label("新しい試合", systemImage: "plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .padding()
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
        .safeAreaInset(edge: .bottom) {
            Button {
                router.navigate(to: .sportSelect)
            } label: {
                Label("新しい試合", systemImage: "plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .padding()
            .background(.bar)
        }
    }

    private func deleteMatch(_ match: Match) {
        for url in match.videoURLs {
            VideoImportService.deleteVideo(at: url)
        }
        modelContext.delete(match)
        matchToDelete = nil
    }
}
