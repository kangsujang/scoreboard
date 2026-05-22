import SwiftUI

enum Route: Hashable {
    case matchSetup
    case scoreEditor(Match)
    case matchDetail(Match)
    case export(Match)

    func hash(into hasher: inout Hasher) {
        switch self {
        case .matchSetup:
            hasher.combine("matchSetup")
        case .scoreEditor(let match):
            hasher.combine("scoreEditor")
            hasher.combine(match.id)
        case .matchDetail(let match):
            hasher.combine("matchDetail")
            hasher.combine(match.id)
        case .export(let match):
            hasher.combine("export")
            hasher.combine(match.id)
        }
    }

    static func == (lhs: Route, rhs: Route) -> Bool {
        switch (lhs, rhs) {
        case (.matchSetup, .matchSetup):
            return true
        case (.scoreEditor(let a), .scoreEditor(let b)):
            return a.id == b.id
        case (.matchDetail(let a), .matchDetail(let b)):
            return a.id == b.id
        case (.export(let a), .export(let b)):
            return a.id == b.id
        default:
            return false
        }
    }
}

@Observable
final class Router {
    var path = NavigationPath()

    func navigate(to route: Route) {
        path.append(route)
    }

    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func popToRoot() {
        path = NavigationPath()
    }
}
