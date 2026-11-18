import Foundation

/// Loads every `Theme-*.json` in the app bundle and remembers which one is
/// selected between launches.
final class ThemeStore: ObservableObject {
    static let defaultThemeID = "pirate"
    private static let selectionKey = "selectedThemeID"

    let themes: [WordTheme]
    @Published var selectedID: String {
        didSet { defaults.set(selectedID, forKey: Self.selectionKey) }
    }

    private let defaults: UserDefaults

    init(themes: [WordTheme]? = nil, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let loaded = (themes ?? Self.loadBundledThemes())
            .filter { !$0.cleanWords.isEmpty }
            .sorted { ($0.order, $0.name) < ($1.order, $1.name) }
        self.themes = loaded.isEmpty ? [Self.fallbackTheme] : loaded

        let saved = defaults.string(forKey: Self.selectionKey)
        let ids = Set(self.themes.map(\.id))
        if let saved, ids.contains(saved) {
            selectedID = saved
        } else if ids.contains(Self.defaultThemeID) {
            selectedID = Self.defaultThemeID
        } else {
            selectedID = self.themes[0].id
        }
    }

    var selected: WordTheme {
        themes.first { $0.id == selectedID } ?? themes[0]
    }

    static func loadBundledThemes(bundle: Bundle = .main) -> [WordTheme] {
        let urls = bundle.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? []
        let decoder = JSONDecoder()
        return urls
            .filter { $0.lastPathComponent.hasPrefix("Theme-") }
            .compactMap { url in
                do {
                    return try decoder.decode(WordTheme.self, from: Data(contentsOf: url))
                } catch {
                    assertionFailure("Couldn't read \(url.lastPathComponent): \(error)")
                    return nil
                }
            }
    }

    /// Only used if no theme files could be read, so the app still works.
    static let fallbackTheme = WordTheme(
        id: "none", name: "None", order: 0, showsNameToEcho: false,
        words: ["apple", "bridge", "candle", "garden", "ladder", "mirror", "pillow", "rocket", "umbrella", "window"]
    )
}
