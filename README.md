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
- None = fully random word. Hard mode, because the Echo doesn't even get a theme.

## UI

- Extremely minimal.
- Rounded-corner boxes everywhere.
- Baskerville font.
- Design reference: [Impeccable](https://impeccable.style/) - a design vocabulary for guiding UI work.

## Specs

- Backwards compatible with basically every iPhone, within reason - must run on iPhone 8 and newer (iOS 16+).
- One phone, passed around. No accounts, no internet required to play.
