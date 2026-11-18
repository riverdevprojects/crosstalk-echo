import Foundation

/// One person at the party.
struct Player: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

/// One of the two teams for a session. Membership stays fixed across
/// "Play again with the same teams"; the Echo is re-picked every round.
struct Team: Identifiable, Hashable {
    /// 0 for Team 1, 1 for Team 2.
    let index: Int
    let players: [Player]

    var id: Int { index }
    var name: String { "Team \(index + 1)" }
}
