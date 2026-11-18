import SwiftUI

@main
struct CrosstalkApp: App {
    @StateObject private var app = AppModel()
    @StateObject private var themes = ThemeStore()
    @StateObject private var templates = PartyTemplateStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
                .environmentObject(themes)
                .environmentObject(templates)
        }
    }
}

/// Which top-level screen is showing. The game itself is one screen whose
/// content follows `GameSession.phase`.
final class AppModel: ObservableObject {
    enum Screen: Equatable {
        case home, themes, setup, game
    }

    @Published var screen: Screen = .home
    @Published private(set) var session: GameSession?
    /// Names on the setup screen. Kept while the app is open, so going back
    /// to Home and starting again doesn't mean retyping everyone.
    @Published var draftPlayers: [Player] = []

    func startGame(names: [String], theme: WordTheme) {
        let players = GameEngine.cleanNames(names).map { Player(name: $0) }
        guard GameEngine.canStart(playerCount: players.count) else { return }
        session = GameSession(players: players, theme: theme)
        screen = .game
    }

    func goHome() {
        screen = .home
        session = nil
    }
}

struct RootView: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        ZStack {
            switch app.screen {
            case .home:
                HomeView()
            case .themes:
                ThemePickerView()
            case .setup:
                SetupView()
            case .game:
                if let session = app.session {
                    GameView(session: session)
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: app.screen)
    }
}
