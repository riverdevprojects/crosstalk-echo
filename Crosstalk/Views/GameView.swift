import SwiftUI

/// Hosts a game session. Content follows the session's phase.
struct GameView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var themes: ThemeStore
    @ObservedObject var session: GameSession

    @State private var confirmingQuit = false

    var body: some View {
        VStack(spacing: 0) {
            if !isResults {
                TopBar(leading: ("Quit", { confirmingQuit = true }))
            }

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
            .transition(.opacity)
        }
        .screen()
        .animation(Style.fade, value: session.phase)
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

/// VoiceOver doesn't notice when a screen is replaced in place or when Done
/// swaps the hinter's name, so these say it out loud.
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

    var body: some View {
        VStack(spacing: Style.gap) {
            VStack(spacing: Style.tightGap) {
                Text(team.name).font(Style.title)
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
                                    Image(systemName: "checkmark")
                                        .font(Style.icon)
                                        .foregroundStyle(Style.muted)
                                }
                            }
                            .box(filled: !done)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(done)
                        .opacity(done ? Style.seenOpacity : 1)
                        .accessibilityLabel(player.name)
                        .accessibilityValue(done ? "Seen" : "")
                        .accessibilityHint(done ? "" : "Shows your card.")
                    }
                }
                .padding(.bottom, Style.screenMargin)
            }
        }
        // Mark the player as seen only after the card has fully closed, so the
        // switch to the next team never happens underneath an open card.
        .fullScreenCover(item: $showing, onDismiss: {
            if let player = justHidden { session.markRevealed(player) }
            justHidden = nil
        }) { player in
            CardView(name: player.name, card: session.round.card(for: player)) {
                justHidden = player
                showing = nil
            }
        }
    }
}

/// A single player's private card.
struct CardView: View {
    let name: String
    let card: Card
    let onHide: () -> Void

    /// The app switcher snapshots whatever is on screen. Hide the card's
    /// contents whenever the app isn't active so the word can't leak there.
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: Style.gap) {
            Text(name)
                .font(Style.caption)
                .foregroundStyle(Style.muted)
                .padding(.top, Style.screenMargin)

            Spacer()

            VStack(spacing: Style.gap) {
                if scenePhase != .active {
                    Text("Hidden")
                        .font(Style.body)
                        .foregroundStyle(Style.muted)
                } else {
                    switch card {
                    case let .word(word):
                        Text("Your word is")
                            .font(Style.body)
                            .foregroundStyle(Style.muted)
                        Text(WordDisplay.format(word))
                            .font(Style.display)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.5)
                            .lineLimit(2)
                    case let .echo(themeName):
                        Text("You are the Echo")
                            .font(Style.display)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.5)
                        Text(themeName.map { "Theme: \($0)" } ?? "No theme. Good luck.")
                            .font(Style.body)
                            .foregroundStyle(Style.muted)
                    }
                }
            }
            .padding(.vertical, Style.screenMargin * 2)
            .box()
            .accessibilityElement(children: .combine)

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
    }
}

// MARK: - Hinting

struct HintView: View {
    @ObservedObject var session: GameSession

    /// The phone gets passed around mid-game, so a quick double tap on Done
    /// is easy and would silently skip a hinter. Taps closer together than
    /// this are ignored.
    private static let doneCooldown: TimeInterval = 0.6
    @State private var lastDoneTap = Date.distantPast

    private func done() {
        let now = Date()
        guard now.timeIntervalSince(lastDoneTap) >= Self.doneCooldown else { return }
        lastDoneTap = now
        session.nextHint()
        // Done stays focused while the name above it changes in place.
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

        VStack(spacing: Style.gap) {
            Spacer()

            VStack(spacing: Style.tightGap) {
                Text(Self.heading(turn))
                    .font(Style.body)
                    .foregroundStyle(Style.muted)
                Text(turn.player.name)
                    .font(Style.display)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)
                    .lineLimit(2)
                Text(turn.team.name)
                    .font(Style.headline)
                    .foregroundStyle(Style.muted)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Self.spoken(turn))
            .id(turn.number)
            .transition(.opacity)

            Spacer()

            VStack(alignment: .leading, spacing: Style.tightGap) {
                Text("Then guessing")
                    .font(Style.headline)
                Text("\(round.echo(of: otherTeam).name) (\(otherTeam.name)) guesses first. If they pass, \(round.echo(of: turn.team).name) (\(turn.team.name)) guesses. Up to \(GameRules.guessesPerEcho) guesses each.")
                    .font(Style.caption)
                    .foregroundStyle(Style.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .box(filled: false)

            Button("Done", action: done)
                .buttonStyle(.primaryBox)
                .accessibilityHint("No one got it. Go to the next hint.")
            Button("Exit") { session.exitRound() }
                .buttonStyle(.secondaryBox)
                .accessibilityHint("An Echo said the word.")
            Text("Done: next hint.  Exit: an Echo said the word.")
                .font(Style.caption)
                .foregroundStyle(Style.muted)
                .padding(.bottom, Style.gap)
        }
        .animation(Style.fade, value: turn.number)
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
                .buttonStyle(.primaryBox)
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

    var body: some View {
        VStack(spacing: Style.gap) {
            Spacer()

            VStack(spacing: Style.tightGap) {
                Text("The word was")
                    .font(Style.body)
                    .foregroundStyle(Style.muted)
                Text(WordDisplay.format(session.round.word))
                    .font(Style.display)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.5)
                    .lineLimit(2)
                Text(winner.map { "\(session.teams[$0].name) wins the round" } ?? "No one got it")
                    .font(Style.headline)
            }
            .accessibilityElement(children: .combine)

            Spacer()

            HStack(spacing: Style.gap) {
                ForEach(session.teams) { team in
                    VStack(spacing: Style.hairGap) {
                        Text(team.name)
                            .font(Style.caption)
                            .foregroundStyle(Style.muted)
                        Text("\(session.scores[team.index])")
                            .font(Style.title)
                            .monospacedDigit()
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
    }
}
