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

    @Published private(set) var templates: [PartyTemplate] = []
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode([PartyTemplate].self, from: data) {
            templates = saved
        }
    }

    /// Saves names under `name`. Saving with an existing party name replaces it.
    func save(name rawName: String, playerNames: [String]) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        let names = GameEngine.cleanNames(playerNames)
        guard !name.isEmpty, !names.isEmpty else { return }
        if let i = templates.firstIndex(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
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
