import SwiftUI

/// Hosts a game session. Content follows the session's phase.
struct GameView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var themes: ThemeStore
    @ObservedObject var session: GameSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.layoutDirection) private var layoutDirection

    @State private var confirmingQuit = false
    @State private var direction = PushDirection()

    var body: some View {
        // Every phase change moves forward except "Back to hints".
        let _ = direction.update(to: session.phase, layoutDirection: layoutDirection) { old, new in
            old == .pickWinner && new == .hinting
        }

        VStack(spacing: 0) {
            if !isResults {
                TopBar(leading: ("Quit", { confirmingQuit = true }))
            }

            // Overlap the old and new phase while they slide, instead of
            // stacking them in the VStack.
            ZStack {
                Group {
                    switch session.phase {
                    case let .reveal(teamIndex):
                        RevealView(session: session, team: session.teams[teamIndex])
                            .id(teamIndex)
                    case .hinting:
                        HintView(session: session)
                    case .pickWinner:
                        WinnerView(session: session)
                    case let .results(winner):
                        ResultsView(session: session, winner: winner) {
                            session.playAgain(theme: themes.selected)
                        } onHome: {
                            app.goHome()
                        }
                    }
                }
                .transition(Style.screenTransition(direction, reduceMotion: reduceMotion))
            }
            .frame(maxHeight: .infinity)
            .settlesAfterChange(of: session.phase)
        }
        .screen()
        .animation(reduceMotion ? Style.fade : Style.push, value: session.phase)
        // Nobody touches the phone while hints are being talked through, so
        // keep the screen from auto-locking for the length of a game.
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        // The game moves on by itself (Team 2's turn, hinting); tell
        // VoiceOver the screen changed so it reads the new one.
        .onChange(of: session.phase) { _ in VoiceOver.screenChanged() }
        .confirmationDialog("End this game?", isPresented: $confirmingQuit, titleVisibility: .visible) {
            Button("End game", role: .destructive) { app.goHome() }
            Button("Keep playing", role: .cancel) {}
        } message: {
            Text("The score for this game will be lost.")
        }
    }

    private var isResults: Bool {
        if case .results = session.phase { return true }
        return false
    }
}

/// VoiceOver doesn't notice when a screen is replaced in place or when
/// Next hint swaps the hinter's name, so these say it out loud.
enum VoiceOver {
    /// Wait for the new content to appear, and don't talk over VoiceOver's
    /// own feedback for the button that was just tapped.
    private static let delay: TimeInterval = 0.3

    static func screenChanged() {
        guard UIAccessibility.isVoiceOverRunning else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            UIAccessibility.post(notification: .screenChanged, argument: nil)
        }
    }

    static func announce(_ text: String) {
        guard UIAccessibility.isVoiceOverRunning else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            UIAccessibility.post(notification: .announcement, argument: text)
        }
    }
}

// MARK: - Reveal

/// One team passes the phone around; each player taps their name to see
/// their card. When everyone has looked, the session moves on by itself.
struct RevealView: View {
    @ObservedObject var session: GameSession
    let team: Team

    @State private var showing: Player?
    @State private var justHidden: Player?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let teamColor = Style.team(team.index)

        VStack(spacing: Style.gap) {
            VStack(spacing: Style.tightGap) {
                Text(team.name)
                    .font(Style.title)
                    .foregroundStyle(teamColor)
                Text("Pass the phone around. Tap your name to see your card.")
                    .font(Style.caption)
                    .foregroundStyle(Style.muted)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, Style.gap)

            ScrollView {
                VStack(spacing: Style.gap) {
                    ForEach(team.players) { player in
                        let done = session.hasRevealed(player)
                        Button {
                            showing = player
                        } label: {
                            HStack {
                                Text(player.name).font(Style.headline)
                                Spacer()
                                if done {
                                    DrawnCheckmark(color: teamColor)
                                }
                            }
                            .box(filled: !done)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.row)
                        .disabled(done)
                        .opacity(done ? Style.seenOpacity : 1)
                        .animation(reduceMotion ? Style.fade : Style.check, value: done)
                        .accessibilityLabel(player.name)
                        .accessibilityValue(done ? "Seen" : "")
                        .accessibilityHint(done ? "" : "Shows your card.")
                    }
                }
                .padding(.bottom, Style.screenMargin)
            }
            // Hide sits over the bottom of this list. Without a pause, the
            // second tap of a quick double tap on Hide could open the next
            // card in front of the wrong person.
            .settlesAfterChange(of: showing, for: Style.cardSettle)
        }
        // Mark the player as seen only after the card has fully closed, so the
        // switch to the next team never happens underneath an open card.
        .fullScreenCover(item: $showing, onDismiss: {
            if let player = justHidden { session.markRevealed(player) }
            justHidden = nil
        }) { player in
            CardView(name: player.name, card: session.round.card(for: player), accent: teamColor) {
                justHidden = player
                showing = nil
            }
        }
    }
}

/// A single player's private card. It slides up face down, then turns over.
struct CardView: View {
    let name: String
    let card: Card
    /// The player's team color.
    var accent: Color = Style.accent
    let onHide: () -> Void

    /// The app switcher snapshots whatever is on screen. Hide the card's
    /// contents whenever the app isn't active so the word can't leak there.
    /// This follows UIKit's app notifications rather than SwiftUI's
    /// `scenePhase`, so it doesn't depend on the scene phase reaching the
    /// full-screen cover the card is shown in.
    @State private var isAppActive = UIApplication.shared.applicationState == .active
    @State private var faceUp = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: Style.gap) {
            Text(name)
                .font(Style.headline)
                .padding(.top, Style.screenMargin)

            Spacer()

            FlipCard(angle: faceUp ? 180 : 0, reduceMotion: reduceMotion) {
                front
                    .cardBox(accent: accent)
            } back: {
                // Same size as the front, without drawing it.
                front
                    .hidden()
                    .overlay(
                        Text("Crosstalk")
                            .font(Style.title)
                            .foregroundStyle(accent)
                    )
                    .cardBox(accent: accent)
            }

            Spacer()

            Text("Remember it, then hide it and pass the phone on.")
                .font(Style.caption)
                .foregroundStyle(Style.muted)
                .multilineTextAlignment(.center)
            Button("Hide", action: onHide)
                .buttonStyle(.primaryBox)
                .padding(.bottom, Style.gap)
        }
        .screen()
        .interactiveDismissDisabled()
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + Style.flipDelay) {
                withAnimation(reduceMotion ? Style.fade : Style.flip) { faceUp = true }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            isAppActive = false
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            isAppActive = true
        }
    }

    private var front: some View {
        VStack(spacing: Style.gap) {
            if !isAppActive {
                Text("Hidden")
                    .font(Style.body)
                    .foregroundStyle(Style.muted)
            } else {
                switch card {
                case let .word(word):
                    Text("Your word is")
                        .font(Style.cardLabel)
                        .foregroundStyle(accent)
                    Text(WordDisplay.format(word))
                        .font(Style.cardWord)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.5)
                        .lineLimit(2)
                case let .echo(themeName):
                    Text("You are the Echo")
                        .font(Style.cardWord)
                        .foregroundStyle(accent)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.5)
                    Text(themeName.map { "Theme: \($0)" } ?? "No theme. Good luck.")
                        .font(Style.body)
                }
            }
        }
        .padding(.vertical, Style.screenMargin)
        .accessibilityElement(children: .combine)
    }
}

/// Shows `back` at 0 degrees and `front` at 180, turning around the vertical
/// axis in between. With Reduce Motion it crossfades instead of turning.
private struct FlipCard<Front: View, Back: View>: View, Animatable {
    var angle: Double
    let reduceMotion: Bool
    let front: Front
    let back: Back

    init(angle: Double, reduceMotion: Bool, @ViewBuilder front: () -> Front, @ViewBuilder back: () -> Back) {
        self.angle = angle
        self.reduceMotion = reduceMotion
        self.front = front()
        self.back = back()
    }

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    var body: some View {
        let showsFront = angle >= 90
        // Both faces are always laid out so the card keeps the front's size
        // while it turns.
        ZStack {
            back
                .opacity(reduceMotion ? 1 - angle / 180 : (showsFront ? 0 : 1))
                .accessibilityHidden(true)
            front
                .rotation3DEffect(.degrees(reduceMotion ? 0 : 180), axis: (x: 0, y: 1, z: 0))
                .opacity(reduceMotion ? angle / 180 : (showsFront ? 1 : 0))
                .accessibilityHidden(!showsFront)
        }
        .rotation3DEffect(.degrees(reduceMotion ? 0 : angle), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
    }
}

// MARK: - Hinting

struct HintView: View {
    @ObservedObject var session: GameSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.layoutDirection) private var layoutDirection

    /// The phone gets passed around mid-game, so a quick double tap on
    /// Next hint is easy and would silently skip a hinter. Taps closer
    /// together than this are ignored.
    private static let nextHintCooldown: TimeInterval = 0.6
    @State private var lastNextHintTap = Date.distantPast
    /// Each new hinter slides in from the trailing edge.
    @State private var forward = PushDirection()

    private func nextHint() {
        let now = Date()
        guard now.timeIntervalSince(lastNextHintTap) >= Self.nextHintCooldown else { return }
        lastNextHintTap = now
        session.nextHint()
        // Next hint stays focused while the name above it changes in place.
        VoiceOver.announce(Self.spoken(session.currentHint))
    }

    private static func heading(_ turn: HintTurn) -> String {
        turn.number == 0 ? "First hint" : "Hint \(turn.number + 1)"
    }

    private static func spoken(_ turn: HintTurn) -> String {
        "\(heading(turn)): \(turn.player.name), \(turn.team.name)"
    }

    var body: some View {
        let turn = session.currentHint
        let round = session.round
        let otherTeam = session.teams[1 - turn.team.index]
        let teamColor = Style.team(turn.team.index)
        let _ = forward.update(to: turn.number, layoutDirection: layoutDirection) { _, _ in false }

        VStack(spacing: Style.gap) {
            Spacer()

            // Old and new hinter overlap while they slide.
            ZStack {
                VStack(spacing: Style.tightGap) {
                    Text(Self.heading(turn))
                        .font(Style.headline)
                        .foregroundStyle(teamColor)
                    Text(turn.player.name)
                        .font(Style.display)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.5)
                        .lineLimit(2)
                    Text(turn.team.name)
                        .font(Style.headline)
                        .foregroundStyle(teamColor)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Self.spoken(turn))
                .id(turn.number)
                .transition(Style.screenTransition(forward, reduceMotion: reduceMotion))
            }

            Spacer()

            VStack(alignment: .leading, spacing: Style.tightGap) {
                Text("Then guessing")
                    .font(Style.headline)
                guessLine("First", echo: round.echo(of: otherTeam), team: otherTeam)
                guessLine("If they pass", echo: round.echo(of: turn.team), team: turn.team)
                Text("Up to \(GameRules.guessesPerEcho) guesses each.")
                    .font(Style.caption)
                    .foregroundStyle(Style.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .box(filled: false)
            .accessibilityElement(children: .combine)

            Button("Next hint", action: nextHint)
                .buttonStyle(.primaryBox)
                .accessibilityHint("No one got it. Go to the next hint.")
            Button("Echo got it") { session.exitRound() }
                .buttonStyle(.secondaryBox)
                .accessibilityHint("An Echo said the word. Ends the round.")
                .padding(.bottom, Style.gap)
        }
        .animation(reduceMotion ? Style.fade : Style.push, value: turn.number)
    }

    /// "First: Bea (Team 2)", with the order label in that team's color.
    private func guessLine(_ order: String, echo: Player, team: Team) -> some View {
        (Text("\(order): ").font(Style.captionStrong).foregroundColor(Style.team(team.index))
            + Text("\(echo.name) (\(team.name))").font(Style.caption))
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Winner

struct WinnerView: View {
    @ObservedObject var session: GameSession

    var body: some View {
        VStack(spacing: Style.gap) {
            Spacer()
            Text("Who said it?")
                .font(Style.title)
            Text("Tap the team whose Echo said the word.")
                .font(Style.caption)
                .foregroundStyle(Style.muted)
            Spacer()

            ForEach(session.teams) { team in
                Button {
                    session.recordWinner(team.index)
                } label: {
                    VStack(spacing: 2) {
                        Text(team.name)
                        Text("Echo: \(session.round.echo(of: team).name)")
                            .font(Style.caption)
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(.teamBox(team.index))
            }
            Button("No one") { session.recordWinner(nil) }
                .buttonStyle(.secondaryBox)
            Button("Back to hints") { session.resumeHinting() }
                .buttonStyle(.textLink)
                .padding(.bottom, Style.gap)
        }
    }
}

// MARK: - Results

struct ResultsView: View {
    @ObservedObject var session: GameSession
    let winner: Int?
    let onPlayAgain: () -> Void
    let onHome: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The winner's point is added on screen once the screen has slid in.
    @State private var pointAdded = false
    @State private var bumping = false

    var body: some View {
        VStack(spacing: Style.gap) {
            Spacer()

            VStack(spacing: Style.tightGap) {
                Text("The word was")
                    .font(Style.body)
                Text(WordDisplay.format(session.round.word))
                    .font(Style.display)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)
                    .lineLimit(2)
                Text(winner.map { "\(session.teams[$0].name) wins the round" } ?? "No one got it")
                    .font(Style.headline)
                    .foregroundStyle(winner.map(Style.team) ?? Style.ink)
            }
            .accessibilityElement(children: .combine)

            Spacer()

            HStack(spacing: Style.gap) {
                ForEach(session.teams) { team in
                    VStack(spacing: Style.hairGap) {
                        Text(team.name)
                            .font(Style.headline)
                            .foregroundStyle(Style.team(team.index))
                        score(for: team.index)
                        Text(team.players.map(\.name).joined(separator: ", "))
                            .font(Style.caption)
                            .foregroundStyle(Style.muted)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                    .box()
                    .accessibilityElement(children: .combine)
                }
            }
            .fixedSize(horizontal: false, vertical: true)

            Spacer()

            Button("Play again with the same teams", action: onPlayAgain)
                .buttonStyle(.primaryBox)
            Button("Home", action: onHome)
                .buttonStyle(.secondaryBox)
                .padding(.bottom, Style.gap)
        }
        .onAppear(perform: addPoint)
    }

    private func score(for index: Int) -> some View {
        let isWinner = index == winner
        let shown = session.scores[index] - (isWinner && !pointAdded ? 1 : 0)
        return Text("\(shown)")
            .font(Style.title)
            .monospacedDigit()
            .numericTransition()
            .scaleEffect(isWinner && bumping ? Style.scoreBumpScale : 1)
            // VoiceOver always hears the real score.
            .accessibilityLabel("\(session.scores[index])")
    }

    private func addPoint() {
        guard winner != nil, !pointAdded else { return }
        if reduceMotion {
            pointAdded = true
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Style.transitionDuration) {
            withAnimation(Style.scoreBump) {
                pointAdded = true
                bumping = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + Style.transitionDuration / 2) {
                withAnimation(Style.scoreBump) { bumping = false }
            }
        }
    }
}

private extension View {
    /// Digits roll to the new value on iOS 17 and later.
    @ViewBuilder func numericTransition() -> some View {
        if #available(iOS 17, *) {
            contentTransition(.numericText())
        } else {
            self
        }
    }
}
