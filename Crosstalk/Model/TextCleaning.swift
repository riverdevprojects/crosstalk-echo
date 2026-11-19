import Foundation

/// The one rule for comparing and cleaning player names and words, so
/// "Ana", " ana " and "ANA" count as the same everywhere in the app.
enum TextCleaning {
    /// Comparison key: trimmed and case-folded.
    static func key(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive], locale: nil)
    }

    /// Trims each item and drops blanks and duplicates (by `key`), keeping
    /// the first spelling and the original order.
    static func clean(_ items: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for raw in items {
            let item = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !item.isEmpty, seen.insert(key(item)).inserted else { continue }
            result.append(item)
        }
        return result
    }
}
