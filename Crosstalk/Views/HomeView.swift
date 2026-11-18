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
        Rule("Teams", "Two teams of at least two. Both teams get the same word."),
        Rule("The Echo", "One player on each team is the Echo. They don't know the word. The app picks them at random."),
        Rule("Hints", "Teams take turns giving one spoken hint at a time, cycling through everyone who isn't the Echo."),
        Rule("Too close", "A hint can't be too close to the word. You're the judges: if the table says it's too close, it doesn't count."),
        Rule("Guessing", "After a hint, the other team's Echo guesses first. If they pass, the hinting team's Echo guesses. Each Echo gets up to two guesses per hint."),
        Rule("Winning", "The first Echo to say the word wins the round."),
        Rule("The phone", "Whoever holds the phone taps Done after each hint, or Exit when an Echo gets the word."),
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
                        VStack(alignment: .leading, spacing: 6) {
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
