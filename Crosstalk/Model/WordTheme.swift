import Foundation

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
    let words: [String]

    private enum CodingKeys: String, CodingKey {
        case id, name, order, showsNameToEcho, words
    }

    init(id: String, name: String, order: Int = 100, showsNameToEcho: Bool = true, words: [String]) {
        self.id = id
        self.name = name
        self.order = order
        self.showsNameToEcho = showsNameToEcho
        self.words = words
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        order = try c.decodeIfPresent(Int.self, forKey: .order) ?? 100
        showsNameToEcho = try c.decodeIfPresent(Bool.self, forKey: .showsNameToEcho) ?? true
        words = try c.decode([String].self, forKey: .words)
    }

    /// Words with blanks and case-insensitive duplicates removed.
    var cleanWords: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for raw in words {
            let word = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !word.isEmpty, seen.insert(word.lowercased()).inserted else { continue }
            result.append(word)
        }
        return result
    }
}
