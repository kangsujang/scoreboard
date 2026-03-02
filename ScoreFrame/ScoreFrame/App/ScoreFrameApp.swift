import SwiftUI
import SwiftData

@main
struct ScoreFrameApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Match.self, ScoreEvent.self])
    }
}
