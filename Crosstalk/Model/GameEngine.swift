import Foundation

/// Fixed game rules.
enum GameRules {
    static let minPlayers = 4
    static let maxPlayers = 20
    static let guessesPerEcho = 2
}

/// What a player sees when they tap their name.
enum Card: Equatable {
    case word(String)
    /// `themeName` is nil when the theme hides itself from the Echo (None).
    case echo(themeName: String?)
}

/// Who gives a given hint.
struct HintTurn: Equatable {
    /// 0-based count of hints given so far this round.
    let number: Int
    let team: Team
    let player: Player
}

/// One word, with the Echos picked for it. Everything here is decided up front
/// so the round is fully deterministic once created.
struct Round: Equatable {
    let word: String
    let theme: WordTheme
    let teams: [Team]
    /// `echoes[i]` is the Echo for `teams[i]`.
    let echoes: [Player]

    func echo(of team: Team) -> Player { echoes[team.index] }

    func isEcho(_ player: Player) -> Bool { echoes.contains(player) }

    /// Everyone on the team except its Echo, in team order.
    func hinters(of team: Team) -> [Player] {
        team.players.filter { $0 != echoes[team.index] }
    }

    func card(for player: Player) -> Card {
        if isEcho(player) {
            return .echo(themeName: theme.showsNameToEcho ? theme.name : nil)
        }
        return .word(word)
    }

    /// Hints alternate between teams, Team 1 first. Within a team, hinters
    /// take turns in order and wrap around, so a bigger team simply cycles
    /// through more people.
    func hintTurn(_ number: Int) -> HintTurn {
        let team = teams[number % 2]
        let hinters = hinters(of: team)
        let player = hinters[(number / 2) % hinters.count]
        return HintTurn(number: number, team: team, player: player)
    }
}

enum GameEngine {
    /// Trims names, drops blanks and case-insensitive duplicates.
    static func cleanNames(_ names: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for raw in names {
            let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, seen.insert(name.lowercased()).inserted else { continue }
            result.append(name)
        }
        return result
    }

    static func canStart(playerCount: Int) -> Bool {
        (GameRules.minPlayers...GameRules.maxPlayers).contains(playerCount)
    }

    /// Shuffles players into two teams. With an odd count, Team 1 gets the
    /// extra player half the time and Team 2 the other half.
    static func makeTeams<R: RandomNumberGenerator>(from players: [Player], using rng: inout R) -> [Team] {
        precondition(players.count >= GameRules.minPlayers, "Need at least \(GameRules.minPlayers) players")
        let shuffled = players.shuffled(using: &rng)
        var sizeA = shuffled.count / 2
        if shuffled.count % 2 == 1, Bool.random(using: &rng) { sizeA += 1 }
        return [
            Team(index: 0, players: Array(shuffled[..<sizeA])),
            Team(index: 1, players: Array(shuffled[sizeA...])),
        ]
    }

    /// Picks a word not in `usedWords` (case-insensitive) when possible, and a
    /// fresh random Echo for each team.
    static func makeRound<R: RandomNumberGenerator>(
        teams: [Team],
        theme: WordTheme,
        usedWords: Set<String>,
        using rng: inout R
    ) -> Round {
        precondition(teams.count == 2 && teams.allSatisfy { $0.players.count >= 2 })
        let pool = theme.cleanWords
        precondition(!pool.isEmpty, "Theme \(theme.id) has no words")
        let fresh = pool.filter { !usedWords.contains($0.lowercased()) }
        let word = (fresh.isEmpty ? pool : fresh).randomElement(using: &rng)!
        let echoes = teams.map { $0.players.randomElement(using: &rng)! }
        return Round(word: word, theme: theme, teams: teams, echoes: echoes)
    }
}
