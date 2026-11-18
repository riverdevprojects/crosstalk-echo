import SwiftUI

/// Every visual decision lives here so the UI can be restyled in one place.
/// Views use these tokens instead of raw fonts, colors, and numbers.
enum Style {
    // MARK: Type (Baskerville ships with iOS; sizes scale with Dynamic Type)

    static func font(_ size: CGFloat, weight: FontWeight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(weight.postScriptName, size: size, relativeTo: style)
    }

    enum FontWeight {
        case regular, semibold, bold
        var postScriptName: String {
            switch self {
            case .regular: return "Baskerville"
            case .semibold: return "Baskerville-SemiBold"
            case .bold: return "Baskerville-Bold"
            }
        }
    }

    static let display = font(44, weight: .semibold, relativeTo: .largeTitle)
    static let title = font(30, weight: .semibold, relativeTo: .title)
    static let headline = font(21, weight: .semibold, relativeTo: .headline)
    static let body = font(19, relativeTo: .body)
    static let caption = font(15, relativeTo: .footnote)

    // MARK: Color (system colors so light and dark mode both work)

    static let ink = Color.primary
    static let muted = Color.secondary
    static let background = Color(uiColor: .systemBackground)
    static let box = Color(uiColor: .secondarySystemBackground)
    static let line = Color(uiColor: .separator)

    // MARK: Shape and spacing

    static let radius: CGFloat = 18
    static let padding: CGFloat = 20
    static let gap: CGFloat = 12
    static let screenMargin: CGFloat = 24
    static let buttonHeight: CGFloat = 56
}

// MARK: - Rounded box

struct BoxModifier: ViewModifier {
    var filled = true
    func body(content: Content) -> some View {
        content
            .padding(Style.padding)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: Style.radius, style: .continuous)
                    .fill(filled ? Style.box : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Style.radius, style: .continuous)
                    .stroke(filled ? Color.clear : Style.line, lineWidth: 1)
            )
    }
}

extension View {
    /// The rounded-corner box used throughout the app.
    func box(filled: Bool = true) -> some View { modifier(BoxModifier(filled: filled)) }

    /// Standard screen chrome: margins, background, Baskerville body text.
    func screen() -> some View {
        self
            .padding(.horizontal, Style.screenMargin)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Style.background.ignoresSafeArea())
            .font(Style.body)
            .foregroundStyle(Style.ink)
    }
}

// MARK: - Buttons

/// Full-width rounded button. `.primary` is solid, `.secondary` is outlined.
struct BoxButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary }
    var kind: Kind = .primary

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Style.headline)
            .multilineTextAlignment(.center)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(maxWidth: .infinity, minHeight: Style.buttonHeight)
            .padding(.horizontal, Style.padding)
            .foregroundStyle(kind == .primary ? Style.background : Style.ink)
            .background(
                RoundedRectangle(cornerRadius: Style.radius, style: .continuous)
                    .fill(kind == .primary ? Style.ink : Style.box)
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.35)
            .contentShape(RoundedRectangle(cornerRadius: Style.radius, style: .continuous))
    }
}

extension ButtonStyle where Self == BoxButtonStyle {
    static var primaryBox: BoxButtonStyle { BoxButtonStyle(kind: .primary) }
    static var secondaryBox: BoxButtonStyle { BoxButtonStyle(kind: .secondary) }
}

/// Small text button for top-bar actions like Back and Quit.
struct TextLinkStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Style.body)
            .foregroundStyle(Style.muted)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.5 : 1)
    }
}

extension ButtonStyle where Self == TextLinkStyle {
    static var textLink: TextLinkStyle { TextLinkStyle() }
}

// MARK: - Scrolling

private struct SnapshotModeKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Set by the snapshot tests: ImageRenderer can't draw ScrollView
    /// contents, so `Scrolling` lays content out flat instead.
    var isSnapshotMode: Bool {
        get { self[SnapshotModeKey.self] }
        set { self[SnapshotModeKey.self] = newValue }
    }
}

/// A vertical ScrollView with the app's standard behavior.
struct Scrolling<Content: View>: View {
    @Environment(\.isSnapshotMode) private var isSnapshotMode
    @ViewBuilder var content: Content

    var body: some View {
        if isSnapshotMode {
            VStack(spacing: 0) {
                content
                Spacer(minLength: 0)
            }
        } else {
            ScrollView { content }
        }
    }
}
