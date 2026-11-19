# Crosstalk

A party game on one iPhone.

## The Game

- 2 teams, at least 2 players each. Both teams get the same word.
- One player per team is the Echo. They don't know the word. The app picks them randomly.
- Everyone else gives hints to get their Echo to say the word before the other team's Echo does.

## How a Round Flows

- Hints alternate between teams, one at a time, cycling through the non-Echo teammates.
- A hint can't be too close to the actual word.
- After a team gives a hint, the OTHER team's Echo gets first shot at guessing. If they pass, the hinting team's Echo guesses.
- Each Echo gets 2 guesses.
- First Echo to say the word wins.

## App Flow

1. Home page: two buttons - Start Game and Change Theme.
2. Start Game - enter everyone's names, or pick from saved party templates if you play with the same people a lot.
3. App sorts everyone into two teams. Team 1 goes first.
4. Team 1 passes the phone around. Each player taps their name to reveal their card. Everyone sees "Your word is Apple" - except the Echo, whose card says "You are the Echo" (plus the theme, unless theme is None).
5. Once Team 1 is done, the screen auto-switches to Team 2. Same thing.
6. Then a screen shows who gives the first hint. One person holds the phone and calls it out.
7. After each verbal hint, the phone holder taps Done (moves to a duplicate screen with the next hinter's name on the other team) or Exit (an Echo got the word, game over).

## Themes

- Change Theme sets the word pool. Pirate theme = parrot, cannon, ship, etc.
- Launch themes: None, Pirate, Animals, Food & Drink, Sports, Movies & TV, Travel.
- None = fully random word. Hard mode, because the Echo doesn't even get a theme.

## UI

- Extremely minimal.
- Rounded-corner boxes everywhere.
- Baskerville font.
- Design reference: [Impeccable](https://impeccable.style/) - a design vocabulary for guiding UI work.

## Specs

- Backwards compatible with basically every iPhone, within reason - must run on iPhone 8 and newer (iOS 16+).
- One phone, passed around. No accounts, no internet required to play.

## House Rules

- Hints are spoken, so the players decide what counts as "too close" to the word.
- Each Echo gets up to 2 guesses per hint. Once both Echos have passed or used their guesses, the next hint is given and the guesses reset. The app doesn't count guesses; the phone holder just taps Done or Exit.
- Showdown: after 10 hints, both Echos keep guessing until one of them runs out of guesses. The hint screen says so from hint 11 on.
- An odd number of players is fine. The bigger team cycles through more hinters.
- After Exit, the app asks which team's Echo said the word and keeps a running score. "Play again with the same teams" picks a new word and new Echos.
- Saved parties are just lists of names. Teams are split fresh every game.
- 4 to 20 players.

## Development

Open `Crosstalk.xcodeproj` in Xcode 16 or newer, set your signing team on the Crosstalk target, and run. No dependencies.

```
Crosstalk/
  CrosstalkApp.swift        App entry and top-level screen switching
  Model/                    Game rules and state (no UI code)
    GameEngine.swift        Teams, Echo picks, word picks, hint order
    GameSession.swift       One sitting: phases, score, play again
    ThemeStore.swift        Loads word lists, remembers the selected theme
    PartyTemplateStore.swift Saved name lists
  Style/Style.swift         Every font, color, radius and spacing value
  Views/                    One file per screen
  Resources/Themes/         Word lists (Theme-*.json)
CrosstalkTests/             Unit tests for the model
```

**Restyling.** All visual values live in `Style/Style.swift`. Views use `Style.title`, `.box()`, `.primaryBox` and so on rather than raw values, so changing the look is mostly a one-file job.

**Adding a theme.** Add a file named `Theme-Whatever.json` to `Crosstalk/Resources/Themes/`. It appears in Change Theme automatically; no code changes.

```json
{
  "id": "space",
  "name": "Space",
  "order": 2,
  "showsNameToEcho": true,
  "words": ["rocket", "planet", "comet"]
}
```

`order` sets its position in the list. `showsNameToEcho: false` hides the theme name from the Echo; that's how None works.

After editing a word list, run `powershell -File tools/check-themes.ps1` (Windows) or `pwsh tools/check-themes.ps1` (Mac). It prints each theme's word count and flags duplicates. Add `-Fix` to remove duplicates and lowercase everything automatically. The unit tests check the same rules.

Launch themes and word counts:

| Theme | Words |
|---|---|
| None | 1,134 |
| Food & Drink | 371 |
| Animals | 266 |
| Sports | 265 |
| Travel | 247 |
| Movies & TV | 230 |
| Pirate | 156 |

Every theme aims for about 1,000 words but stops where it would need obscure words. Only None reaches 1,000.

**App icon.** `tools/make-icon.ps1` draws the placeholder icon (one speech bubble on a neutral background). Replace `Crosstalk/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` with any 1024×1024 PNG without transparency; Xcode generates every other size.

**Tests.** Product > Test in Xcode, or:

```
xcodebuild test -project Crosstalk.xcodeproj -scheme Crosstalk -destination 'platform=iOS Simulator,name=iPhone 16'
```

CI runs the same tests on every pull request.
