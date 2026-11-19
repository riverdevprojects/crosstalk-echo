# Impeccable audit: Crosstalk (iOS)

Run on 2026-11-18 against PR #1 with the Impeccable skill installed in Claude Code (github.com/pbakaus/impeccable): `/impeccable init`, then repeated `audit`, `harden` and `polish` rounds until a pass found nothing material. Scope was code quality only. No visual redesign commands were run and the UI styling was not changed. `init` wrote [PRODUCT.md](../PRODUCT.md).

An earlier pass applied Impeccable's published references by hand, before the skill was installed. Its fixes are listed at the end.

Evidence comes from the source, the unit tests, and Simulator snapshots of every screen rendered in CI: iPhone 8 and iPhone 16 sizes, light and dark, plus a worst case of 20 players with 20-character names at the largest allowed text size. Nothing was tested on a physical device, and VoiceOver announcements were checked in code, not with VoiceOver running.

## Audit health score

| # | Dimension | Score | Key finding |
|---|-----------|-------|-------------|
| 1 | Accessibility | 4 | Dynamic Type is capped at the largest standard size (accessibility sizes off) |
| 2 | Performance | 4 | -- |
| 3 | Appearance & Theming | 4 | -- |
| 4 | Platform Conformance | 2 | Custom navigation: no edge-swipe back, no system navigation bar |
| 5 | Adaptivity | 3 | iPhone portrait only (on purpose for a pass-around game) |
| **Total** | | **17/20** | **Good** |

## Platform conformance verdict

The app reads as native: system colors, SF Symbols, system alerts, confirmation dialogs, context menus, full-screen covers, and correct safe areas. It departs from iOS conventions in two places. Both are design decisions, so they're left for River:

- **Navigation is a hand-rolled screen switch with text "Back" links**, not a `NavigationStack`. iOS's left-edge swipe-back gesture doesn't work on Change Theme or Players, and there's no system navigation bar or large title.
- **Baskerville is used for all text, including controls.** The README asks for it. Impeccable's iOS guidance would keep San Francisco for controls and use a brand face only for display text.

## Round 1

| Sev | Issue | Fix |
|---|---|---|
| P2 | A double tap on "Play again" used up a second word | Only works from the results screen; tests added |
| P2 | VoiceOver didn't announce the next hinter after Done, or the automatic switch to Team 2 | Announced |
| P2 | Deleting a saved party was only possible by touch and hold | Delete action for VoiceOver |
| P3 | Reveal rows put hint text in the VoiceOver label | Name, value ("Seen"), and hint split |
| P3 | Repeated spacing, tap-size, opacity, animation and icon values typed into views | Style tokens with the same values |
| P2 | No evidence that fixed-height screens fit with long names at large text | Stress snapshots added; all fit on iPhone 8 |

## Round 2

| Sev | Issue | Fix |
|---|---|---|
| P1 | Buttons on consecutive screens line up, so a quick double tap made a second choice on the next screen: Exit then "No one", a winner then "Play again", Start Game then a name card, Home's Start Game then a saved party | Taps ignored for 0.5s after every screen change (`SettleAfterChange.swift`) |
| P2 | The card's app-switcher privacy relied on SwiftUI's scene phase reaching a full-screen cover, and snapshots only ever showed "Hidden" | Uses UIKit's resign/become-active notifications; snapshots now show real card contents |

## Round 3

| Sev | Issue | Fix |
|---|---|---|
| P2 | A quick double tap on Hide could open the next name's card in front of the wrong person | Name list ignores taps for 0.5s after a card opens or closes |

## Round 4: color and motion (requested UI change)

River asked for a visual update: team colors, a neutral accent, slide transitions and motion, a distinct word card, and the hint buttons renamed to "Next hint" and "Echo got it". The Impeccable skill wasn't installed on the machine that did this work, so its audit and polish checks were applied by hand, using the same snapshots plus mid-transition frames captured in the Simulator.

| Sev | Issue | Fix |
|---|---|---|
| P2 | During a phase change the old and new screens stacked inside one VStack, so the layout jumped mid-slide | Each changing area sits in a ZStack, so the two overlap while they slide |
| P2 | Going back, the returning screen is opaque and covered the outgoing one, which only drifted 30% | Back slides the outgoing screen fully off to the trailing edge |
| P2 | SwiftUI builds a removed view's transition from its last render, so the direction (forward or back) could be stale | The direction lives in a reference object that the transition reads when it starts |
| P2 | A shorter tap pause after Hide would make a stray tap more likely to open the next card in front of the wrong person | Screen changes now pause for 0.35s, the length of the slide; the name list keeps its 0.5s pause after a card closes |
| P3 | A pale ring of team tint showed outside the card's border | Tint drawn inside the border |
| P3 | The new hinter's slide ignored right-to-left layouts | Uses the layout direction like the screen pushes |

Checked: every new color pair is at least 4.5:1 in light and dark mode (team 1 blue 5.6 to 9.5, team 2 orange 5.1 to 10, accent 12 to 16, secondary text 6.6 to 10); blue and orange stay distinct for common color blindness. With Reduce Motion on, slides, the card flip, button scaling and the score bump become fades or are skipped. VoiceOver hears the real score, not the animated one, and the card's face-down side is hidden from it. The 20-player, largest-text screens still fit on iPhone 8.

## Hardening checks that passed

- **Rapid taps:** Next hint has its own cooldown; every screen change pauses input for the length of its slide and every card close for 0.5s; model actions check the current phase.
- **Extreme content:** 20 players with 20-character names at the largest text size fit every fixed-height screen on iPhone 8.
- **Empty states:** no saved parties hides the section, and missing theme files fall back to a built-in word list.
- **Duplicate data:** duplicate names, words, and theme ids are all handled.
- **Emoji and accented names** compare correctly (case-folded).
- **No network use,** so there are no network error states.

## Positive findings

- System background and text colors, plus team and accent colors that each have a light and dark value in `Style.swift`. Dark mode works without separate assets.
- Every visual value is in `Style.swift`. Views use tokens; the only raw numbers left are local hit-area insets and text scale factors.
- Platform controls are used where they fit (alerts, confirmation dialogs, context menus, full-screen covers).
- Game logic is separate from the UI and covered by unit tests.

## Recommended next steps (River's call; all involve UI design)

1. **[P1] Navigation:** move Change Theme and Players onto a `NavigationStack` to get edge-swipe back and a system navigation bar.
2. **[P2] Typography:** decide whether controls should use San Francisco, with Baskerville kept for display text.
3. **[P3] Accessibility sizes:** once the layouts scroll or adapt, remove the Dynamic Type cap in `CrosstalkApp.swift`.

## Earlier hand-applied pass

Before the skill was installed: Done double-tap cooldown, screen kept awake during a game, the word hidden from the app switcher, unreadable saved parties kept aside instead of overwritten, a 20-character name limit, 44pt touch targets, wrapping button labels, the Dynamic Type cap, Save disabled without a party name, sentence-case words with acronyms kept, a duplicate VoiceOver "Selected" removed, one shared text-cleaning rule, and dead code removed.
