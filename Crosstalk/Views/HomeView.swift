import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var themes: ThemeStore
    @State private var showingRules = false

    var body: some View {
        VStack(spacing: Style.gap) {
            Spacer()

            Text("Crosstalk")
                .font(Style.display)
            Text("Theme: \(themes.selected.name)")
                .font(Style.caption)
                .foregroundStyle(Style.muted)

            Spacer()

            Button("Start Game") { app.screen = .setup }
                .buttonStyle(.primaryBox)
            Button("Change Theme") { app.screen = .themes }
                .buttonStyle(.secondaryBox)

            Button("How to play") { showingRules = true }
                .buttonStyle(.textLink)
                .padding(.bottom, Style.gap)
        }
        .screen()
        .sheet(isPresented: $showingRules) { RulesView() }
    }
}

struct RulesView: View {
    @Environment(\.dismiss) private var dismiss

    private struct Rule: Identifiable {
        let title: String
        let text: String
        var id: String { title }
        init(_ title: String, _ text: String) { self.title = title; self.text = text }
    }

    private let rules: [Rule] = [
        Rule("Teams", "Two teams of at least two. Both get the same word."),
        Rule("The Echo", "One random player per team is the Echo. They don't know the word."),
        Rule("Hints", "Teams take turns giving one spoken hint. Everyone but the Echo takes a turn."),
        Rule("Too close", "A hint can't be too close to the word. The table decides."),
        Rule("Guessing", "After a hint, the other team's Echo guesses first, then the hinting team's Echo. Two guesses each per hint."),
        Rule("Showdown", "After \(GameRules.hintsBeforeShowdown) hints, both Echos guess until one runs out of guesses."),
        Rule("Winning", "First Echo to say the word wins."),
        Rule("The phone", "After each hint, tap Next hint, or Echo got it when an Echo says the word."),
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Close") { dismiss() }.buttonStyle(.textLink)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: Style.gap) {
                    Text("How to play")
                        .font(Style.title)
                        .padding(.bottom, Style.gap)
                    ForEach(rules) { rule in
                        VStack(alignment: .leading, spacing: Style.tightGap) {
                            Text(rule.title).font(Style.headline)
                            Text(rule.text)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .box()
                    }
                }
                .padding(.bottom, Style.screenMargin)
            }
        }
        .screen()
    }
}
