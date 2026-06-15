import SwiftUI
import SwiftData

@main
struct OverScoreApp: App {
    let container: ModelContainer
    @State private var storeManager = StoreManager()

    init() {
        do {
            container = try ModelContainer(for: Match.self, ScoreEvent.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        AdManager.shared.configure()
        AdManager.shared.loadInterstitialAd()
        cleanupOnLaunch()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(storeManager)
        }
        .modelContainer(container)
    }

    private func cleanupOnLaunch() {
        // エクスポート一時ファイルを削除
        VideoImportService.cleanupTempExportFiles()

        // 孤立した動画ファイルを削除
        let context = ModelContext(container)
        let referencedURLs = collectReferencedVideoURLs(context: context)
        VideoImportService.cleanupOrphanedVideos(referencedURLs: referencedURLs)
    }

    private func collectReferencedVideoURLs(context: ModelContext) -> Set<URL> {
        var urls = Set<URL>()
        do {
            let matches = try context.fetch(FetchDescriptor<Match>())
            for match in matches {
                for url in match.videoURLs {
                    urls.insert(url)
                }
            }
        } catch {
            // フェッチ失敗時は安全のため何も削除しない
        }
        return urls
    }
}
