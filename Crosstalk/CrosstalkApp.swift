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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.layoutDirection) private var layoutDirection
    @State private var direction = PushDirection()

    /// Position in the flow: Home, then Change Theme or Players, then the game.
    private static func depth(_ screen: AppModel.Screen) -> Int {
        switch screen {
        case .home: return 0
        case .themes, .setup: return 1
        case .game: return 2
        }
    }

    var body: some View {
        let _ = direction.update(to: app.screen, layoutDirection: layoutDirection) {
            Self.depth($1) < Self.depth($0)
        }

        ZStack {
            Group {
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
            .transition(Style.screenTransition(direction, reduceMotion: reduceMotion))
        }
        .settlesAfterChange(of: app.screen)
        .animation(reduceMotion ? Style.fade : Style.push, value: app.screen)
        // Text still scales with the user's setting, up to the largest
        // standard size. The accessibility sizes beyond that would push the
        // Next hint / Echo got it buttons off the fixed-height game screens.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }
}
