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
    /// Between a label and the line just under it.
    static let tightGap: CGFloat = 6
    /// Between lines inside one small group.
    static let hairGap: CGFloat = 4
    /// Apple's minimum tap size. Small controls get at least this much
    /// tappable area, even when they look smaller.
    static let minTouchTarget: CGFloat = 44

    // MARK: State and motion

    static let disabledOpacity: Double = 0.35
    /// Names that have already seen their card.
    static let seenOpacity: Double = 0.5
    static let pressedOpacity: Double = 0.7
    /// Screen and phase changes crossfade.
    static let fade = Animation.easeInOut(duration: 0.2)

    // MARK: Icons (SF Symbols)

    static let icon = Font.body.weight(.semibold)
    static let smallIcon = Font.footnote.weight(.semibold)
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
            // Shrink a little to stay on one line; at large text sizes wrap
            // to a second centered line rather than cutting the label off.
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.85)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, minHeight: Style.buttonHeight)
            .padding(.horizontal, Style.padding)
            .foregroundStyle(kind == .primary ? Style.background : Style.ink)
            .background(
                RoundedRectangle(cornerRadius: Style.radius, style: .continuous)
                    .fill(kind == .primary ? Style.ink : Style.box)
            )
            .opacity(isEnabled ? (configuration.isPressed ? Style.pressedOpacity : 1) : Style.disabledOpacity)
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
            .frame(minWidth: Style.minTouchTarget, minHeight: Style.minTouchTarget, alignment: .leading)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.5 : 1)
    }
}

extension ButtonStyle where Self == TextLinkStyle {
    static var textLink: TextLinkStyle { TextLinkStyle() }
}
