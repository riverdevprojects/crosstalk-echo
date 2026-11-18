# Impeccable audit: Crosstalk (iOS)

Run on 2026-11-18 against PR #1, scoped to code quality and polish (`audit`, `harden`, `polish`) only. No visual redesign commands were run and the UI styling was not changed. The checks follow Impeccable's published `audit.native.md`, `ios.md`, `harden.md` and `polish.md` references (github.com/pbakaus/impeccable). The CLI wasn't installed on the build machine, so the references were applied by hand and the report is saved here instead of through Impeccable's storage helper.

Evidence comes from reading the source, the unit tests, and Simulator snapshots of every screen from CI (iPhone 8 and iPhone 16 sizes, light and dark). Nothing was tested on a physical device.

## Audit health score

| # | Dimension | Score | Key finding |
|---|-----------|-------|-------------|
| 1 | Accessibility | 3 | Text scales with Dynamic Type up to the largest standard size, but the accessibility sizes are capped |
| 2 | Performance | 4 | -- |
| 3 | Appearance & Theming | 4 | -- |
| 4 | Platform Conformance | 2 | Custom navigation: no edge-swipe back, no system navigation bar |
| 5 | Adaptivity | 3 | iPhone portrait only (on purpose for a pass-around game) |
| **Total** | | **16/20** | **Good** |

## Platform conformance verdict

The app reads as native: system colors, SF Symbols, system alerts, confirmation dialogs, context menus, full-screen covers, and correct safe areas. It departs from iOS conventions in two places. Both are design decisions, so they're left for River:

- **Navigation is a hand-rolled screen switch with text "Back" links**, not a `NavigationStack`. iOS's left-edge swipe-back gesture doesn't work on Change Theme or Players, and there's no system navigation bar or large title. Fixing this means changing the navigation model, which is a structural UI decision.
- **Baskerville is used for all text, including controls.** The README asks for it. Impeccable's iOS guidance would keep San Francisco for controls and use a brand face only for display text.

## Fixed in this pass

| Sev | Issue | Where | Fix |
|---|---|---|---|
| P1 | A double-tap on Done skipped a hinter | Hint screen | 0.6s cooldown on Done |
| P1 | Screen auto-locked mid-game | Game | Idle timer off while a game is on screen |
| P1 | The word showed in the app switcher if the app was backgrounded with a card open | Card | Card contents hidden while the app isn't active |
| P1 | Saved parties could be wiped after a failed load | Saved parties | Unreadable data kept aside; never overwritten |
| P2 | No limit on name length; very long names broke the large name displays | Players | 20-character limit, also applied when loading saved parties |
| P2 | "Add", "Back" and "Quit" touch targets were under 44pt | Players, top bars | 44×44pt targets with no visual change |
| P2 | Long button labels were cut off at large text sizes | All buttons | Wrap to two centered lines |
| P2 | Accessibility text sizes pushed Done/Exit off the fixed-height game screens | App | Text scales up to the largest standard size |
| P2 | Save party with a blank name failed silently | Players | Save disabled until a name is entered |
| P3 | Words displayed as "Tug Of War" and "Dvd" | Card, results | Sentence case, acronyms kept ("Smart TV") |
| P3 | VoiceOver said "Selected" twice on the chosen theme | Change Theme | Checkmark hidden from VoiceOver |
| P3 | Three slightly different copies of the name and word cleaning rule | Model | One shared `TextCleaning` rule |
| P3 | Dead code (`revealingTeam`, `roundsPlayed`) | GameSession | Removed |

## Hardening checks that passed

- **Rapid taps:** Exit, winner selection, Hide, and Start Game are all guarded or safe to repeat.
- **Empty states:** no saved parties hides the section, and missing theme files fall back to a built-in word list.
- **Duplicate data:** duplicate names, words, and theme ids are all handled.
- **Emoji and accented names** compare correctly (case-folded).
- **No network use,** so there are no network error states.

## Positive findings

- Semantic system colors throughout. Dark mode works without separate assets.
- Every visual value is in one place (`Style.swift`), with no hard-coded colors or sizes in views.
- Platform controls are used where they fit (alerts, confirmation dialogs, context menus, full-screen covers).
- Game logic is separate from the UI and covered by unit tests.

## Recommended next steps (River's call; all involve UI design)

1. **[P1] Navigation:** move Change Theme and Players onto a `NavigationStack` to get edge-swipe back and a system navigation bar.
2. **[P2] Typography:** decide whether controls should use San Francisco, with Baskerville kept for display text.
3. **[P3] Accessibility sizes:** once the layouts scroll or adapt, remove the Dynamic Type cap in `CrosstalkApp.swift`.
