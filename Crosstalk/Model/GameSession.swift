import Foundation

/// A sitting of the game: fixed teams, a running score, and the current round.
final class GameSession: ObservableObject {
    enum Phase: Equatable {
        /// Players on `teamIndex` are tapping their names to see their cards.
        case reveal(teamIndex: Int)
        /// Hints are being given; see `currentHint`.
        case hinting
        /// Someone tapped Exit; asking whose Echo said the word.
        case pickWinner
        /// Round over. `winner` is a team index, or nil for "no one".
        case results(winner: Int?)
    }

    let teams: [Team]
    @Published private(set) var round: Round
    @Published private(set) var phase: Phase = .reveal(teamIndex: 0)
    @Published private(set) var scores: [Int] = [0, 0]
    @Published private(set) var revealed: Set<Player.ID> = []
    @Published private(set) var hintNumber = 0

    private var usedWords: Set<String> = []
    private var rng: any RandomNumberGenerator

    init(players: [Player], theme: WordTheme, rng: any RandomNumberGenerator = SystemRandomNumberGenerator()) {
        var generator = AnyRNG(rng)
        teams = GameEngine.makeTeams(from: players, using: &generator)
        round = GameEngine.makeRound(teams: teams, theme: theme, usedWords: [], using: &generator)
        self.rng = generator.base
        usedWords.insert(TextCleaning.key(round.word))
    }

    var currentHint: HintTurn { round.hintTurn(hintNumber) }

    func hasRevealed(_ player: Player) -> Bool { revealed.contains(player.id) }

    /// Call after a player has seen their card and hidden it again. When the
    /// whole team has looked, moves on to the other team, then to hinting.
    func markRevealed(_ player: Player) {
        guard case let .reveal(index) = phase, teams[index].players.contains(player) else { return }
        revealed.insert(player.id)
        guard teams[index].players.allSatisfy({ revealed.contains($0.id) }) else { return }
        phase = index == 0 ? .reveal(teamIndex: 1) : .hinting
    }

    /// The phone holder tapped Done: next hinter, on the other team.
    func nextHint() {
        guard phase == .hinting else { return }
        hintNumber += 1
    }

    /// The phone holder tapped Exit: an Echo got the word (or they're stopping).
    func exitRound() {
        guard phase == .hinting else { return }
        phase = .pickWinner
    }

    /// Tapped Exit by mistake.
    func resumeHinting() {
        guard phase == .pickWinner else { return }
        phase = .hinting
    }

    /// `teamIndex` is the team whose Echo said the word, or nil for no one.
    func recordWinner(_ teamIndex: Int?) {
        guard phase == .pickWinner else { return }
        if let teamIndex { scores[teamIndex] += 1 }
        phase = .results(winner: teamIndex)
    }

    /// Same teams, new word, re-picked Echos. Score carries over.
    func playAgain(theme: WordTheme) {
        var generator = AnyRNG(rng)
        round = GameEngine.makeRound(teams: teams, theme: theme, usedWords: usedWords, using: &generator)
        rng = generator.base
        usedWords.insert(TextCleaning.key(round.word))
        revealed = []
        hintNumber = 0
        phase = .reveal(teamIndex: 0)
    }
}

/// Lets the session hold any generator (seeded ones in tests, the system one
/// in the app) while still calling the generic engine functions.
struct AnyRNG: RandomNumberGenerator {
    var base: any RandomNumberGenerator
    init(_ base: any RandomNumberGenerator) { self.base = base }
    mutating func next() -> UInt64 { base.next() }
}
