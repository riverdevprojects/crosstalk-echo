import SwiftUI

struct ThemePickerView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var themes: ThemeStore

    var body: some View {
        VStack(spacing: 0) {
            TopBar(leading: ("Back", { app.screen = .home }))

            ScrollView {
                VStack(spacing: Style.gap) {
                    Text("Theme")
                        .font(Style.title)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, Style.gap)

                    ForEach(themes.themes) { theme in
                        Button {
                            themes.selectedID = theme.id
                        } label: {
                            ThemeRow(theme: theme, isSelected: theme.id == themes.selectedID)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, Style.screenMargin)
            }
        }
        .screen()
    }
}

private struct ThemeRow: View {
    let theme: WordTheme
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(theme.name).font(Style.headline)
                Text(theme.showsNameToEcho
                     ? "\(theme.cleanWords.count) words"
                     : "Any word. The Echo isn't told the theme.")
                    .font(Style.caption)
                    .foregroundStyle(Style.muted)
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
                    .accessibilityHidden(true) // the row already carries the selected trait
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .box(filled: isSelected)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Minimal top bar with optional text actions on each side.
struct TopBar: View {
    var leading: (String, () -> Void)? = nil
    var trailing: (String, () -> Void)? = nil

    var body: some View {
        HStack {
            if let leading {
                Button(leading.0, action: leading.1).buttonStyle(.textLink)
            }
            Spacer()
            if let trailing {
                Button(trailing.0, action: trailing.1).buttonStyle(.textLink)
            }
        }
        .frame(minHeight: 44)
    }
}
