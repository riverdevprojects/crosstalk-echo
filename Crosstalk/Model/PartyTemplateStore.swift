import Foundation

/// A saved list of names for a group that plays together often.
/// Teams are never saved; they're split fresh every game.
struct PartyTemplate: Identifiable, Hashable, Codable {
    var id = UUID()
    var name: String
    var playerNames: [String]
}

final class PartyTemplateStore: ObservableObject {
    private static let key = "partyTemplates"
    /// Where unreadable saved data is moved, so a later save can't erase it.
    static let unreadableBackupKey = "partyTemplates.unreadable"

    @Published private(set) var templates: [PartyTemplate] = []
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        guard let data = defaults.data(forKey: Self.key) else { return }
        do {
            templates = try JSONDecoder().decode([PartyTemplate].self, from: data)
        } catch {
            // Don't let the next save overwrite parties we couldn't read (for
            // example after a format change). Keep the raw bytes aside.
            defaults.set(data, forKey: Self.unreadableBackupKey)
            defaults.removeObject(forKey: Self.key)
        }
    }

    /// Saves names under `name`. Saving with an existing party name replaces it.
    func save(name rawName: String, playerNames: [String]) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        let names = GameEngine.cleanNames(playerNames)
        guard !name.isEmpty, !names.isEmpty else { return }
        if let i = templates.firstIndex(where: { TextCleaning.key($0.name) == TextCleaning.key(name) }) {
            templates[i].name = name
            templates[i].playerNames = names
        } else {
            templates.append(PartyTemplate(name: name, playerNames: names))
        }
        persist()
    }

    func delete(_ template: PartyTemplate) {
        templates.removeAll { $0.id == template.id }
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(templates) {
            defaults.set(data, forKey: Self.key)
        }
    }
}
