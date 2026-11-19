# Product

<!-- impeccable:product-schema 1 -->

## Platform

ios

## Users
Groups of 4 to 20 people playing in person: friends and families, mixed ages, sitting together. One iPhone is passed around the room. Each player handles the phone only briefly (to reveal a card); one person, the phone holder, keeps it during the hint phase and taps Done or Exit after each spoken hint.

## Product Purpose
Crosstalk runs the bookkeeping for a spoken word-guessing party game so the group can focus on playing: it splits teams, secretly picks a word and one Echo per team, shows each player their card privately, calls out whose turn it is to hint, and keeps a running score. Success is a round that starts in under a minute and never needs anyone to remember whose turn it is.

## Positioning
Two teams race on the same word, and the guesser (the Echo) does not know it. The app never judges hints or counts guesses; the players police the spoken parts. One phone, no accounts, no internet.

## Operating Context
- The phone is passed hand to hand; private information (the word, who is the Echo) must never be visible to the wrong person, including in the app switcher.
- A party setting: noisy, distracted, quick taps, people of varying familiarity with phones.
- Played offline. Nothing is synced or uploaded.

## Capabilities and Constraints
- SwiftUI, iOS 16+, iPhone 8 and newer, iPhone only, portrait only. No third-party dependencies. Xcode 16+ project.
- 4 to 20 players. Teams are "Team 1" and "Team 2" (no custom names), split fresh every game; uneven teams are fine.
- Card reveal: each player taps their name once; after Hide the name is checked off and cannot be reopened.
- Hint phase: Done (next hinter, alternating teams) or Exit (an Echo said the word). The app does not count guesses.
- Round end: pick which team's Echo said the word (or no one), running score, "Play again with the same teams" (new word, new Echos, no repeated words in a sitting), Home.
- Themes are data: one `Theme-*.json` per theme. Launch set and sizes are final: None 1,134; Food & Drink 371; Animals 266; Sports 265; Travel 247; Movies & TV 230; Pirate 156. None hides the theme name from the Echo.
- Saved parties are name lists only. Selected theme is remembered locally.
- Display name "Crosstalk", bundle ID com.riverdevprojects.crosstalk. Signing team is set by River.

## Brand Commitments
- Extremely minimal UI: rounded-corner boxes, Baskerville, nothing decorative. System colors with dark mode.
- River designs the final visual UI himself. Automated design work on this project is limited to code quality, hardening, and polish that does not change the look. All visual values live in `Crosstalk/Style/Style.swift`.
- Placeholder app icon (one speech bubble, neutral background, no text) drawn by `tools/make-icon.ps1`; River will replace it.

## Evidence on Hand
- Rules and app flow: `README.md`.
- Word lists: `Crosstalk/Resources/Themes/`.
- CI renders every screen (iPhone 8 and iPhone 16 sizes, light and dark) as the `screen-snapshots` artifact.
- No testimonials, users, metrics, or store listing exist. Do not invent them.

## Product Principles
1. The phone is a referee, not a player: it tracks turns and score, never judges hints.
2. Secrets stay secret while the phone changes hands.
3. Every screen is usable in one glance by someone who has never seen the app.
4. Content is data: themes and parties change without code.
5. Clean structure River can restyle beats finished visuals.

## Accessibility & Inclusion
iOS defaults are the bar: Dynamic Type, light and dark mode, VoiceOver labels, 44pt minimum touch targets. Word lists stay family-friendly.
