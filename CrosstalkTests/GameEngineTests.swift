import XCTest
@testable import Crosstalk

/// Deterministic generator so tests are repeatable.
struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        // SplitMix64
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

final class GameEngineTests: XCTestCase {
    private let theme = WordTheme(id: "t", name: "Test", words: ["apple", "bridge", "candle"])
    private let hidden = WordTheme(id: "none", name: "None", showsNameToEcho: false, words: ["apple"])

    private func players(_ n: Int) -> [Player] {
        (1...n).map { Player(name: "P\($0)") }
    }

    // MARK: Names

    func testCleanNamesTrimsAndDropsBlanksAndDuplicates() {
        XCTAssertEqual(
            GameEngine.cleanNames(["  Ana ", "", "ana", "Ben", "   ", "BEN", "Cy"]),
            ["Ana", "Ben", "Cy"]
        )
    }

    func testPlayerCountLimits() {
        XCTAssertFalse(GameEngine.canStart(playerCount: 3))
        XCTAssertTrue(GameEngine.canStart(playerCount: 4))
        XCTAssertTrue(GameEngine.canStart(playerCount: 20))
        XCTAssertFalse(GameEngine.canStart(playerCount: 21))
    }

    // MARK: Teams

    func testTeamsUseEveryoneOnceAndAreBalanced() {
        for n in GameRules.minPlayers...GameRules.maxPlayers {
            for seed in 0..<20 {
                var rng = SeededRNG(seed: UInt64(seed))
                let all = players(n)
                let teams = GameEngine.makeTeams(from: all, using: &rng)
                XCTAssertEqual(teams.map(\.index), [0, 1])
                let members = teams.flatMap(\.players)
                XCTAssertEqual(Set(members), Set(all))
                XCTAssertEqual(members.count, n)
                XCTAssertLessThanOrEqual(abs(teams[0].players.count - teams[1].players.count), 1)
                XCTAssertGreaterThanOrEqual(teams.map(\.players.count).min()!, 2)
            }
        }
    }

    func testOddCountSometimesFavorsEachTeam() {
        var team1Bigger = false, team2Bigger = false
        for seed in 0..<50 {
            var rng = SeededRNG(seed: UInt64(seed))
            let teams = GameEngine.makeTeams(from: players(5), using: &rng)
            if teams[0].players.count == 3 { team1Bigger = true } else { team2Bigger = true }
        }
        XCTAssertTrue(team1Bigger && team2Bigger)
    }

    // MARK: Rounds

    func testRoundPicksOneEchoPerTeamFromThatTeam() {
        var rng = SeededRNG(seed: 1)
        let teams = GameEngine.makeTeams(from: players(6), using: &rng)
        let round = GameEngine.makeRound(teams: teams, theme: theme, usedWords: [], using: &rng)
        XCTAssertTrue(teams[0].players.contains(round.echoes[0]))
        XCTAssertTrue(teams[1].players.contains(round.echoes[1]))
        XCTAssertTrue(theme.words.contains(round.word))
    }

    func testCardsShowWordToHintersAndThemeToEchoes() {
        var rng = SeededRNG(seed: 2)
        let teams = GameEngine.makeTeams(from: players(4), using: &rng)
        let round = GameEngine.makeRound(teams: teams, theme: theme, usedWords: [], using: &rng)
        for team in teams {
            for player in team.players {
                if player == round.echo(of: team) {
                    XCTAssertEqual(round.card(for: player), .echo(themeName: "Test"))
                } else {
                    XCTAssertEqual(round.card(for: player), .word(round.word))
                }
            }
        }
    }

    func testNoneThemeHidesThemeFromEcho() {
        var rng = SeededRNG(seed: 3)
        let teams = GameEngine.makeTeams(from: players(4), using: &rng)
        let round = GameEngine.makeRound(teams: teams, theme: hidden, usedWords: [], using: &rng)
        XCTAssertEqual(round.card(for: round.echoes[0]), .echo(themeName: nil))
    }

    func testRoundAvoidsUsedWordsUntilPoolRunsOut() {
        var rng = SeededRNG(seed: 4)
        let teams = GameEngine.makeTeams(from: players(4), using: &rng)
        for seed in 0..<20 {
            var r = SeededRNG(seed: UInt64(seed))
            let round = GameEngine.makeRound(teams: teams, theme: theme, usedWords: ["apple", "bridge"], using: &r)
            XCTAssertEqual(round.word, "candle")
        }
        let exhausted = GameEngine.makeRound(teams: teams, theme: theme, usedWords: ["apple", "bridge", "candle"], using: &rng)
        XCTAssertTrue(theme.words.contains(exhausted.word))
    }

    // MARK: Hint order

    func testHintsAlternateTeamsStartingWithTeam1AndCycleHinters() {
        // Team 1 has 4 players (3 hinters), Team 2 has 3 (2 hinters).
        let a = players(4), b = (5...7).map { Player(name: "P\($0)") }
        let teams = [Team(index: 0, players: a), Team(index: 1, players: b)]
        let round = Round(word: "apple", theme: theme, teams: teams, echoes: [a[0], b[0]])

        let turns = (0..<10).map { round.hintTurn($0) }
        XCTAssertEqual(turns.map(\.team.index), [0, 1, 0, 1, 0, 1, 0, 1, 0, 1])
        XCTAssertEqual(turns.map(\.player.name), ["P2", "P6", "P3", "P7", "P4", "P6", "P2", "P7", "P3", "P6"])
        XCTAssertFalse(turns.contains { round.isEcho($0.player) })
    }

    // MARK: Session

    func testSessionFlowRevealThenHintThenScore() {
        let session = GameSession(players: players(5), theme: theme, rng: SeededRNG(seed: 5))
        XCTAssertEqual(session.phase, .reveal(teamIndex: 0))

        // Revealing someone on the wrong team does nothing.
        session.markRevealed(session.teams[1].players[0])
        XCTAssertTrue(session.revealed.isEmpty)

        for p in session.teams[0].players { session.markRevealed(p) }
        XCTAssertEqual(session.phase, .reveal(teamIndex: 1))
        for p in session.teams[1].players { session.markRevealed(p) }
        XCTAssertEqual(session.phase, .hinting)

        XCTAssertEqual(session.currentHint.team.index, 0)
        session.nextHint()
        XCTAssertEqual(session.currentHint.team.index, 1)

        session.exitRound()
        XCTAssertEqual(session.phase, .pickWinner)
        session.resumeHinting()
        XCTAssertEqual(session.phase, .hinting)
        XCTAssertEqual(session.hintNumber, 1)

        session.exitRound()
        session.recordWinner(1)
        XCTAssertEqual(session.phase, .results(winner: 1))
        XCTAssertEqual(session.scores, [0, 1])
    }

    func testPlayAgainKeepsTeamsAndScoreButResetsRound() {
        let session = GameSession(players: players(6), theme: theme, rng: SeededRNG(seed: 6))
        let teams = session.teams
        let firstWord = session.round.word
        for p in teams.flatMap(\.players) { session.markRevealed(p) }
        session.nextHint()
        session.exitRound()
        session.recordWinner(0)

        session.playAgain(theme: theme)
        XCTAssertEqual(session.teams, teams)
        XCTAssertEqual(session.scores, [1, 0])
        XCTAssertEqual(session.phase, .reveal(teamIndex: 0))
        XCTAssertTrue(session.revealed.isEmpty)
        XCTAssertEqual(session.hintNumber, 0)
        XCTAssertNotEqual(session.round.word, firstWord)
    }

    func testNoWinnerDoesNotScore() {
        let session = GameSession(players: players(4), theme: theme, rng: SeededRNG(seed: 7))
        for p in session.teams.flatMap(\.players) { session.markRevealed(p) }
        session.exitRound()
        session.recordWinner(nil)
        XCTAssertEqual(session.scores, [0, 0])
        XCTAssertEqual(session.phase, .results(winner: nil))
    }

    // MARK: Bundled data

    func testBundledThemesLoadAndAreUsable() {
        let themes = ThemeStore.loadBundledThemes(bundle: Bundle(for: GameSession.self))
        XCTAssertEqual(
            Set(themes.map(\.id)),
            ["none", "pirate", "animals", "food-drink", "sports", "movies-tv", "travel"]
        )
        XCTAssertEqual(Set(themes.map(\.order)).count, themes.count, "Each theme needs its own sort order")
        for theme in themes {
            XCTAssertGreaterThanOrEqual(theme.cleanWords.count, 150, theme.id)
            XCTAssertEqual(theme.cleanWords.count, theme.words.count, "\(theme.id) has blank or duplicate words")
            for word in theme.words {
                XCTAssertEqual(word, word.lowercased(), "\(theme.id): \(word) should be lowercase")
                XCTAssertEqual(word, word.trimmingCharacters(in: .whitespaces), "\(theme.id): '\(word)' has stray spaces")
            }
        }
        XCTAssertGreaterThanOrEqual(themes.first { $0.id == "none" }!.cleanWords.count, 1000)
        XCTAssertEqual(themes.first { $0.id == "none" }?.showsNameToEcho, false)
    }

    func testPartyTemplatesSaveReplaceAndDelete() {
        let defaults = UserDefaults(suiteName: "CrosstalkTests-\(UUID())")!
        let store = PartyTemplateStore(defaults: defaults)
        store.save(name: " Friday ", playerNames: ["Ana", "ana", "Ben"])
        XCTAssertEqual(store.templates.map(\.name), ["Friday"])
        XCTAssertEqual(store.templates[0].playerNames, ["Ana", "Ben"])

        store.save(name: "friday", playerNames: ["Cy", "Di"])
        XCTAssertEqual(store.templates.count, 1)
        XCTAssertEqual(PartyTemplateStore(defaults: defaults).templates[0].playerNames, ["Cy", "Di"])

        store.delete(store.templates[0])
        XCTAssertTrue(PartyTemplateStore(defaults: defaults).templates.isEmpty)
    }

    func testThemeSelectionIsRemembered() {
        let defaults = UserDefaults(suiteName: "CrosstalkTests-\(UUID())")!
        let themes = [theme, hidden, WordTheme(id: "pirate", name: "Pirate", words: ["ship"])]
        XCTAssertEqual(ThemeStore(themes: themes, defaults: defaults).selectedID, "pirate")
        let store = ThemeStore(themes: themes, defaults: defaults)
        store.selectedID = "none"
        XCTAssertEqual(ThemeStore(themes: themes, defaults: defaults).selectedID, "none")
    }
}
