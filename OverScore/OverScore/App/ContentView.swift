import SwiftUI

struct ContentView: View {
    @State private var router = Router()

    var body: some View {
        NavigationStack(path: $router.path) {
            MatchListView()
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .matchSetup:
                        MatchSetupView()
                    case .scoreEditor(let match):
                        ScoreEditorView(match: match)
                    case .matchDetail(let match):
                        MatchDetailView(match: match)
                    case .export(let match):
                        ExportView(match: match)
                    }
                }
        }
        .environment(router)
    }
}
