import SwiftUI

/// Enter everyone's names, or load a saved party.
struct SetupView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var themes: ThemeStore
    @EnvironmentObject private var templates: PartyTemplateStore

    @State private var newName = ""
    @State private var showingSaveAlert = false
    @State private var partyName = ""
    @FocusState private var nameFieldFocused: Bool

    private var players: [Player] { app.draftPlayers }
    private var trimmedNewName: String { newName.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isDuplicate: Bool {
        players.contains { TextCleaning.key($0.name) == TextCleaning.key(trimmedNewName) }
    }
    private var isFull: Bool { players.count >= GameRules.maxPlayers }
    private var canAdd: Bool { !trimmedNewName.isEmpty && !isDuplicate && !isFull }
    private var canStart: Bool { GameEngine.canStart(playerCount: players.count) }

    var body: some View {
        VStack(spacing: 0) {
            TopBar(leading: ("Back", { app.screen = .home }), trailing: saveAction)

            ScrollView {
                VStack(spacing: Style.gap) {
                    Text("Players")
                        .font(Style.title)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    addField

                    ForEach(players) { player in
                        PlayerRow(name: player.name) { remove(player) }
                    }

                    if !templates.templates.isEmpty {
                        savedParties
                    }
                }
                .padding(.bottom, Style.screenMargin)
            }
            .scrollDismissesKeyboard(.interactively)

            VStack(spacing: 8) {
                Text(countText)
                    .font(Style.caption)
                    .foregroundStyle(Style.muted)
                Button("Start Game") {
                    app.startGame(names: players.map(\.name), theme: themes.selected)
                }
                .buttonStyle(.primaryBox)
                .disabled(!canStart)
            }
            .padding(.vertical, Style.gap)
        }
        .screen()
        .alert("Save party", isPresented: $showingSaveAlert) {
            TextField("Party name", text: $partyName)
            Button("Save") {
                templates.save(name: partyName, playerNames: players.map(\.name))
            }
            .disabled(partyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Saves these \(players.count) names so you can pick them next time. Teams are still split fresh each game.")
        }
    }

    private var saveAction: (String, () -> Void)? {
        guard !players.isEmpty else { return nil }
        return ("Save party", {
            partyName = ""
            showingSaveAlert = true
        })
    }

    private var countText: String {
        let n = players.count
        if n < GameRules.minPlayers {
            let more = GameRules.minPlayers - n
            return "\(n) \(n == 1 ? "player" : "players"). Add \(more) more to start."
        }
        return "\(n) players"
    }

    private var addField: some View {
        VStack(alignment: .leading, spacing: Style.tightGap) {
            HStack(spacing: Style.gap) {
                TextField("Add a name", text: $newName)
                    .font(Style.body)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .focused($nameFieldFocused)
                    .onSubmit(add)
                    .disabled(isFull)
                    .onChange(of: newName) { value in
                        if value.count > GameRules.maxNameLength {
                            newName = String(value.prefix(GameRules.maxNameLength))
                        }
                    }
                Button("Add", action: add)
                    .font(Style.headline)
                    .foregroundStyle(Style.ink)
                    // 44pt touch target without making the box any taller.
                    .frame(minWidth: Style.minTouchTarget, minHeight: Style.minTouchTarget)
                    .contentShape(Rectangle())
                    .padding(.vertical, -10)
                    .disabled(!canAdd)
                    .opacity(canAdd ? 1 : Style.disabledOpacity)
            }
            .box()

            if isDuplicate && !trimmedNewName.isEmpty {
                Text("\(trimmedNewName) is already playing.")
                    .font(Style.caption)
                    .foregroundStyle(Style.muted)
                    .padding(.horizontal, Style.hairGap)
            } else if isFull {
                Text("That's the maximum of \(GameRules.maxPlayers) players.")
                    .font(Style.caption)
                    .foregroundStyle(Style.muted)
                    .padding(.horizontal, Style.hairGap)
            }
        }
    }

    private var savedParties: some View {
        VStack(alignment: .leading, spacing: Style.gap) {
            Text("Saved parties")
                .font(Style.headline)
                .padding(.top, Style.gap)
            ForEach(templates.templates) { template in
                Button {
                    // Trim to the name limit before de-duplicating, so two long
                    // names can't collapse into the same short one.
                    let names = template.playerNames.map { String($0.prefix(GameRules.maxNameLength)) }
                    app.draftPlayers = GameEngine.cleanNames(names)
                        .prefix(GameRules.maxPlayers)
                        .map { Player(name: $0) }
                } label: {
                    VStack(alignment: .leading, spacing: Style.hairGap) {
                        Text(template.name).font(Style.headline)
                        Text(template.playerNames.joined(separator: ", "))
                            .font(Style.caption)
                            .foregroundStyle(Style.muted)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .box(filled: false)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button(role: .destructive) {
                        templates.delete(template)
                    } label: {
                        Label("Delete party", systemImage: "trash")
                    }
                }
                .accessibilityHint("Loads these names.")
                // VoiceOver users reach Delete from the actions rotor.
                .accessibilityAction(named: "Delete party") { templates.delete(template) }
            }
        }
    }

    private func add() {
        guard canAdd else { return }
        app.draftPlayers.append(Player(name: trimmedNewName))
        newName = ""
        nameFieldFocused = true
    }

    private func remove(_ player: Player) {
        app.draftPlayers.removeAll { $0.id == player.id }
    }
}

private struct PlayerRow: View {
    let name: String
    let onRemove: () -> Void

    var body: some View {
        HStack {
            Text(name).font(Style.body)
            Spacer()
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(Style.smallIcon)
                    .foregroundStyle(Style.muted)
                    .frame(width: Style.minTouchTarget, height: Style.minTouchTarget)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Remove \(name)")
            .padding(.vertical, -12)
            .padding(.trailing, -12)
        }
        .box()
    }
}
