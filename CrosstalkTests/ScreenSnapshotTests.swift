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

    private func render<V: View>(
        _ name: String,
        dark: Bool = false,
        textSize: DynamicTypeSize = .large,
        @ViewBuilder _ view: () -> V
    ) throws {
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
                .environment(\.dynamicTypeSize, textSize)
            let image = try snapshot(content, size: size, dark: dark)
            let data = try XCTUnwrap(image.pngData())
            let suffix = (dark ? "-dark" : "") + (textSize == .large ? "" : "-\(textSize)")
            try data.write(to: outputDir.appendingPathComponent("\(name)-\(device)\(suffix).png"))
        }
    }

    /// Hosts the view in a real window and draws the window's hierarchy, so
    /// ScrollView, TextField and other UIKit-backed views render as they do
    /// in the app (ImageRenderer leaves those blank).
    private func snapshot<V: View>(_ view: V, size: CGSize, dark: Bool) throws -> UIImage {
        let scene = try XCTUnwrap(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first,
            "No window scene in the test host"
        )
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: size)
        window.overrideUserInterfaceStyle = dark ? .dark : .light
        let host = UIHostingController(rootView: view)
        window.rootViewController = host
        window.isHidden = false
        defer { window.isHidden = true }

        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        // Give SwiftUI a moment to finish its first layout and render pass.
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))

        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = true
        return UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
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

    /// Worst case for the screens that don't scroll: 20 players with
    /// 20-character names, at the largest text size the app allows.
    func testRenderStressScreens() throws {
        let big = DynamicTypeSize.xxxLarge
        let names = (1...GameRules.maxPlayers).map { i in
            String("Maximilian Featherstonehaugh \(i)".prefix(GameRules.maxNameLength))
        }
        let theme = ThemeStore.loadBundledThemes(bundle: Bundle(for: GameSession.self)).first { $0.id == "pirate" }!
        let s = GameSession(players: names.map { Player(name: $0) }, theme: theme, rng: SeededRNG(seed: 7))

        try render("20-stress-home", textSize: big) { HomeView() }
        try render("21-stress-reveal", textSize: big) { GameView(session: s) }
        try render("22-stress-card-echo", textSize: big) { CardView(name: names[0], card: .echo(themeName: "Movies & TV")) {} }
        try render("23-stress-card-word", textSize: big) { CardView(name: names[0], card: .word("tug of war")) {} }
        for p in s.teams.flatMap(\.players) { s.markRevealed(p) }
        try render("24-stress-hint", textSize: big) { GameView(session: s) }
        s.exitRound()
        try render("25-stress-who-said-it", textSize: big) { GameView(session: s) }
        s.recordWinner(1)
        try render("26-stress-results", textSize: big) { GameView(session: s) }
    }
}
