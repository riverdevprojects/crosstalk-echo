import SwiftUI
import XCTest
@testable import Crosstalk

/// Renders each screen to a PNG so layouts can be eyeballed without a device.
/// Only runs when SNAPSHOT_DIR is set (CI sets TEST_RUNNER_SNAPSHOT_DIR);
/// it never fails on looks, it just writes images.
@MainActor
final class ScreenSnapshotTests: XCTestCase {
    private var outputDir: URL!

    override func setUpWithError() throws {
        guard let dir = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"], !dir.isEmpty else {
            throw XCTSkip("SNAPSHOT_DIR not set")
        }
        outputDir = URL(fileURLWithPath: dir)
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
    }

    private let sizes: [(String, CGSize)] = [
        ("iPhone8", CGSize(width: 375, height: 667)),
        ("iPhone16", CGSize(width: 393, height: 852)),
    ]

    private func session(players n: Int = 5) -> GameSession {
        let theme = ThemeStore.loadBundledThemes(bundle: Bundle(for: GameSession.self)).first { $0.id == "pirate" }!
        let names = ["Alex", "Bea", "Cam", "Dana", "Eli", "Fern", "Gus"].prefix(n)
        return GameSession(players: names.map { Player(name: $0) }, theme: theme, rng: SeededRNG(seed: 42))
    }

    private func render<V: View>(_ name: String, dark: Bool = false, @ViewBuilder _ view: () -> V) throws {
        let app = AppModel()
        app.draftPlayers = ["Alex", "Bea", "Cam"].map { Player(name: $0) }
        let themes = ThemeStore(defaults: UserDefaults(suiteName: "snap-\(UUID())")!)
        let templates = PartyTemplateStore(defaults: UserDefaults(suiteName: "snap-\(UUID())")!)
        templates.save(name: "Friday crew", playerNames: ["Alex", "Bea", "Cam", "Dana", "Eli", "Fern"])

        for (device, size) in sizes {
            let content = view()
                .environmentObject(app)
                .environmentObject(themes)
                .environmentObject(templates)
                .frame(width: size.width, height: size.height)
                .environment(\.colorScheme, dark ? .dark : .light)
                .environment(\.isSnapshotMode, true)
            let renderer = ImageRenderer(content: content)
            renderer.scale = 2
            let image = try XCTUnwrap(renderer.uiImage, "Couldn't render \(name)")
            let data = try XCTUnwrap(image.pngData())
            try data.write(to: outputDir.appendingPathComponent("\(name)-\(device)\(dark ? "-dark" : "").png"))
        }
    }

    func testRenderScreens() throws {
        try render("01-home") { HomeView() }
        try render("01-home", dark: true) { HomeView() }
        try render("02-themes") { ThemePickerView() }
        try render("03-setup") { SetupView() }
        try render("04-rules") { RulesView() }

        let s = session()
        try render("05-reveal-team1") { GameView(session: s) }

        let word = s.round.card(for: s.teams[0].players.first { !s.round.isEcho($0) }!)
        try render("06-card-word") { CardView(name: "Bea", card: word) {} }
        try render("07-card-echo") { CardView(name: "Alex", card: .echo(themeName: "Pirate")) {} }
        try render("08-card-echo-none") { CardView(name: "Alex", card: .echo(themeName: nil)) {} }

        s.markRevealed(s.teams[0].players[0])
        try render("09-reveal-partial") { GameView(session: s) }
        for p in s.teams.flatMap(\.players) { s.markRevealed(p) }
        try render("10-first-hint") { GameView(session: s) }
        s.nextHint()
        try render("11-hint-2") { GameView(session: s) }
        try render("11-hint-2", dark: true) { GameView(session: s) }
        s.exitRound()
        try render("12-who-said-it") { GameView(session: s) }
        s.recordWinner(0)
        try render("13-results") { GameView(session: s) }
    }
}
