import SwiftUI
import UIKit

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
    /// Short labels inside a caption line, such as the guessing order.
    static let captionStrong = font(15, weight: .bold, relativeTo: .footnote)
    /// The word (or "You are the Echo") on a player's card.
    static let cardWord = font(54, weight: .bold, relativeTo: .largeTitle)
    /// Small label above the word on a card ("Your word is").
    static let cardLabel = font(17, weight: .semibold, relativeTo: .subheadline)

    // MARK: Color
    //
    // Each color has a light and a dark value. Every pair below has at least
    // 4.5:1 contrast against both the screen background and the box fill, and
    // against the label color drawn on top of it when used as a fill.

    static let ink = Color.primary
    /// Secondary text. Darker than the system's secondary label so small
    /// captions stay readable at a glance (light 7.4:1, dark 10:1).
    static let muted = dynamic(light: 0x55555C, dark: 0xB4B4BB)
    static let background = Color(uiColor: .systemBackground)
    static let box = Color(uiColor: .secondarySystemBackground)
    static let line = Color(uiColor: .separator)

    /// Neutral accent for primary buttons: deep slate in light mode, pale
    /// slate in dark mode. Button labels use `onAccent`.
    static let accent = dynamic(light: 0x26303D, dark: 0xDCE3EB)
    /// Text and icons drawn on a filled accent or team color.
    static let onAccent = background

    /// Team 1 is blue, Team 2 is orange: different in hue and readable for
    /// the common forms of color blindness.
    static let team1 = dynamic(light: 0x1F5BC4, dark: 0x7EB0FF)
    static let team2 = dynamic(light: 0xB5400C, dark: 0xFF9A62)

    /// The color for team index 0 or 1.
    static func team(_ index: Int) -> Color { index == 0 ? team1 : team2 }

    /// Light wash of a team color behind a player's card.
    static let cardTintOpacity: Double = 0.08

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }

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

    /// The player's card: larger corners, more room, a team-colored border.
    static let cardRadius: CGFloat = 28
    static let cardPadding: CGFloat = 32
    static let cardBorder: CGFloat = 3

    // MARK: State

    static let disabledOpacity: Double = 0.35
    /// Names that have already seen their card.
    static let seenOpacity: Double = 0.55
    static let pressedOpacity: Double = 0.85
    /// Buttons shrink this much while pressed.
    static let pressedScale: CGFloat = 0.96

    // MARK: Motion
    //
    // Views check Reduce Motion and use `fade` instead of slides, flips and
    // scaling when it is on.

    /// Length of a screen-to-screen push. Taps are ignored for exactly this
    /// long after a screen change (see `SettleAfterChange`).
    static let transitionDuration: TimeInterval = 0.35
    /// Screen and phase changes slide.
    static let push = Animation.easeInOut(duration: transitionDuration)
    /// After a card opens or closes, the name list ignores taps this long.
    /// Longer than a screen push on purpose: a stray tap here would show a
    /// card to the wrong person, and the card's own slide takes about this long.
    static let cardSettle: TimeInterval = 0.5
    /// Used in place of motion when Reduce Motion is on.
    static let fade = Animation.easeInOut(duration: 0.2)
    /// Button press feedback.
    static let press = Animation.spring(response: 0.25, dampingFraction: 0.6)
    /// The card turning over.
    static let flip = Animation.spring(response: 0.55, dampingFraction: 0.8)
    /// How long the card shows its back before it turns over: long enough
    /// for the card screen to finish sliding up.
    static let flipDelay: TimeInterval = 0.35
    /// The checkmark drawing itself next to a name.
    static let check = Animation.easeOut(duration: 0.35)
    /// The winning score ticking up.
    static let scoreBump = Animation.spring(response: 0.4, dampingFraction: 0.5)
    static let scoreBumpScale: CGFloat = 1.25
    /// The outgoing screen slides this fraction of its width while the new
    /// one slides all the way in.
    static let pushParallax: CGFloat = 0.3

    /// The transition for screens that replace each other. Forward pushes
    /// in from the trailing edge; back pushes in from the leading edge.
    static func screenTransition(_ direction: PushDirection, reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : .push(direction)
    }

    // MARK: Icons (SF Symbols)

    static let icon = Font.body.weight(.semibold)
    static let smallIcon = Font.footnote.weight(.semibold)
    static let checkSize: CGFloat = 18
    static let checkLineWidth: CGFloat = 2.5
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

// MARK: - Push transition

/// Which way the last screen change went. A reference type on purpose: SwiftUI
/// builds a removed view's transition from that view's last render, so the
/// transition reads the direction when the animation starts instead.
final class PushDirection {
    var forward = true
    var rightToLeft = false

    private var last: Any?

    /// Call from `body` with the screen being shown. When it differs from
    /// the last one, `isBack(old, new)` decides the direction.
    func update<Value: Equatable>(
        to value: Value,
        layoutDirection: LayoutDirection = .leftToRight,
        isBack: (Value, Value) -> Bool
    ) {
        rightToLeft = layoutDirection == .rightToLeft
        if let previous = last as? Value, previous != value {
            forward = !isBack(previous, value)
        }
        last = value
    }
}

/// Moves a view horizontally by a fraction of its own width.
private struct SlideEffect: GeometryEffect {
    enum Role { case insertion, removal }

    /// 0 = in place, 1 = fully moved.
    var progress: CGFloat
    let role: Role
    let direction: PushDirection

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        // Forward: the new screen comes in from the trailing edge on top while
        // the old one drifts a little toward leading. Back: the new screen
        // comes in from the leading edge and the old one leaves fully toward
        // trailing, so neither screen is ever hidden behind the other.
        let towardTrailing = (role == .insertion) == direction.forward
        let distance = role == .removal && direction.forward ? Style.pushParallax : 1
        // Trailing is right in left-to-right languages.
        let trailingSign: CGFloat = direction.rightToLeft ? -1 : 1
        let sign = towardTrailing ? trailingSign : -trailingSign
        return ProjectionTransform(CGAffineTransform(translationX: sign * size.width * distance * progress, y: 0))
    }
}

extension AnyTransition {
    /// iOS-style push between screens; see `SlideEffect`.
    static func push(_ direction: PushDirection) -> AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: SlideEffect(progress: 1, role: .insertion, direction: direction),
                identity: SlideEffect(progress: 0, role: .insertion, direction: direction)
            ),
            removal: AnyTransition.modifier(
                active: SlideEffect(progress: 1, role: .removal, direction: direction),
                identity: SlideEffect(progress: 0, role: .removal, direction: direction)
            )
            .combined(with: .opacity)
        )
    }
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

/// The player's private card: bigger, roomier, and edged in the team color
/// so it never looks like a row in a list.
struct CardBoxModifier: ViewModifier {
    let accent: Color
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: Style.cardRadius, style: .continuous)
        return content
            .padding(Style.cardPadding)
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    shape.fill(Style.background)
                    shape.fill(accent.opacity(Style.cardTintOpacity))
                }
            )
            .overlay(shape.strokeBorder(accent, lineWidth: Style.cardBorder))
    }
}

extension View {
    /// The rounded-corner box used throughout the app.
    func box(filled: Bool = true) -> some View { modifier(BoxModifier(filled: filled)) }

    /// A player's card, edged in `accent`.
    func cardBox(accent: Color) -> some View { modifier(CardBoxModifier(accent: accent)) }

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

/// Shrinks a pressed control with a quick spring (or just dims it when
/// Reduce Motion is on).
private struct PressEffect: ViewModifier {
    let isPressed: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed && !reduceMotion ? Style.pressedScale : 1)
            .opacity(isPressed ? Style.pressedOpacity : 1)
            .animation(reduceMotion ? nil : Style.press, value: isPressed)
    }
}

/// Full-width rounded button. `.primary` is solid accent, `.secondary` is a
/// plain box. `.team(i)` is solid in that team's color.
struct BoxButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, team(Int) }
    var kind: Kind = .primary

    @Environment(\.isEnabled) private var isEnabled

    private var fill: Color {
        switch kind {
        case .primary: return Style.accent
        case .secondary: return Style.box
        case let .team(index): return Style.team(index)
        }
    }

    private var label: Color {
        if case .secondary = kind { return Style.ink }
        return Style.onAccent
    }

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
            .foregroundStyle(label)
            .background(
                RoundedRectangle(cornerRadius: Style.radius, style: .continuous)
                    .fill(fill)
            )
            .contentShape(RoundedRectangle(cornerRadius: Style.radius, style: .continuous))
            .modifier(PressEffect(isPressed: configuration.isPressed))
            .opacity(isEnabled ? 1 : Style.disabledOpacity)
    }
}

extension ButtonStyle where Self == BoxButtonStyle {
    static var primaryBox: BoxButtonStyle { BoxButtonStyle(kind: .primary) }
    static var secondaryBox: BoxButtonStyle { BoxButtonStyle(kind: .secondary) }
    static func teamBox(_ index: Int) -> BoxButtonStyle { BoxButtonStyle(kind: .team(index)) }
}

/// A tappable box in a list (names, themes, saved parties): the label draws
/// its own box; this adds the press spring.
struct RowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .modifier(PressEffect(isPressed: configuration.isPressed))
    }
}

extension ButtonStyle where Self == RowButtonStyle {
    static var row: RowButtonStyle { RowButtonStyle() }
}

/// Small text button for top-bar actions like Back and Quit.
struct TextLinkStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Style.body)
            .foregroundStyle(Style.ink)
            .frame(minWidth: Style.minTouchTarget, minHeight: Style.minTouchTarget, alignment: .leading)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.5 : 1)
    }
}

extension ButtonStyle where Self == TextLinkStyle {
    static var textLink: TextLinkStyle { TextLinkStyle() }
}

// MARK: - Checkmark

/// A checkmark that draws itself in when it appears.
struct DrawnCheckmark: View {
    var color: Color = Style.ink
    @State private var drawn: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        CheckmarkShape()
            .trim(from: 0, to: drawn)
            .stroke(color, style: StrokeStyle(lineWidth: Style.checkLineWidth, lineCap: .round, lineJoin: .round))
            .frame(width: Style.checkSize, height: Style.checkSize)
            .accessibilityHidden(true)
            .onAppear {
                if reduceMotion {
                    drawn = 1
                } else {
                    withAnimation(Style.check) { drawn = 1 }
                }
            }
    }
}

private struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.08, y: rect.midY + rect.height * 0.04))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.38, y: rect.maxY - rect.height * 0.14))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.06, y: rect.minY + rect.height * 0.14))
        return path
    }
}
