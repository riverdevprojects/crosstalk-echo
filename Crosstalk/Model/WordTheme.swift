import Foundation

/// How a word from a list is shown on screen. Lists are stored lowercase;
/// this gives sentence case ("Tug of war", not "Tug Of War") and keeps
/// known acronyms upper case ("Smart TV", "3D glasses").
enum WordDisplay {
    static let acronyms: Set<String> = ["dvd", "vhs", "gps", "tv", "rv", "3d"]

    static func format(_ word: String) -> String {
        let tokens = word.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        return tokens.enumerated().map { index, token in
            if acronyms.contains(token.lowercased()) { return token.uppercased() }
            guard index == 0, let first = token.first else { return token }
            return first.uppercased() + token.dropFirst()
        }
        .joined(separator: " ")
    }
}

/// A word pool, loaded from a `Theme-*.json` file in the app bundle.
///
/// Adding or changing a theme is a data edit: drop a new `Theme-Something.json`
/// into `Crosstalk/Resources/Themes/` with this shape and it shows up in
/// Change Theme automatically.
///
/// ```json
/// {
///   "id": "pirate",
///   "name": "Pirate",
///   "order": 1,
///   "showsNameToEcho": true,
///   "words": ["parrot", "cannon", "ship"]
/// }
/// ```
///
/// `showsNameToEcho: false` is what makes "None" hard mode: the Echo's card
/// doesn't mention a theme.
struct WordTheme: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    /// Sort position in the Change Theme list. Lower comes first.
    var order: Int = 100
    var showsNameToEcho: Bool = true
    /// The words exactly as written in the file.
    let words: [String]
    /// `words` with blanks and duplicates removed (see `TextCleaning`).
    /// Computed once, since lists never change after loading.
    let cleanWords: [String]

    private enum CodingKeys: String, CodingKey {
        case id, name, order, showsNameToEcho, words
    }

    init(id: String, name: String, order: Int = 100, showsNameToEcho: Bool = true, words: [String]) {
        self.id = id
        self.name = name
        self.order = order
        self.showsNameToEcho = showsNameToEcho
        self.words = words
        cleanWords = TextCleaning.clean(words)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        order = try c.decodeIfPresent(Int.self, forKey: .order) ?? 100
        showsNameToEcho = try c.decodeIfPresent(Bool.self, forKey: .showsNameToEcho) ?? true
        words = try c.decode([String].self, forKey: .words)
        cleanWords = TextCleaning.clean(words)
    }
}
