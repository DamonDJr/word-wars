# Word Wars: App Store listing copy

For **App Store Connect → Distribution → your version → English (U.S.)**. Written
for 1.5.5 on 2026-09-23 and checked against the code rather than memory; the
facts it states are listed at the bottom with where each one lives, so the next
rewrite can re-check them instead of trusting this file.

Screenshots for this copy: `tools/store-shots.sh` → `build/shots/store/`.
The App Preview: `build/trailer/word-wars-preview.mp4` (see
`tools/previewcut.py`).

---

## Description

> Limit 4,000 characters. This is 2,169.

```
Your endings become their beginnings.

Type a word and its last letters get stamped onto a block that drops on
your opponent's board. To clear it, they need a word that STARTS with
those letters. Whatever they type to clear it lands right back on you.

FRIENDSHIP sends them SHIP. They answer with SHIPMENTS and you get
MENT. It's a word chain where every link is an attack.

PLAY YOUR FRIENDS
Send an invite link and they're in your room with one tap, or share a
five-character room code. Quick Match finds whoever else is looking
for a game right now. No account needed.

FAST OR LONG
Fire words without pausing and your chain makes every block you send
bigger. Or go long: seven- and ten-letter words hit harder on their
own. Break several blocks with one word and the combo carries into
your next attack.

MODES
VERSUS: one on one against another player, or a CPU when no one's
around.
SOLO: up to three CPU rivals at once, picked from seven with their own
play styles. Metronome never breaks its chain. Berserker only attacks.
Bulwark answers everything. Wordsmith does it all, fast.
DAILY: 75 seconds on the same board as everyone else. One run a day.
Keep your streak going.
SURVIVAL: no clock, and the pressure keeps rising. See how long you
last.
WEEKLY: four new missions every week.
PRACTICE: a five-step lesson, then an endless training board with no
opponent.

A KEYBOARD BUILT FOR IT
The letter you press pops up above your thumb so you catch a mistap
right away, and the keyboard adapts to where your thumbs actually
land.

A REAL DICTIONARY
Almost 350,000 valid words. Blocks are stamped from common words, so
there's always an answer. Letters are worth their Scrabble values.

UNLOCK AS YOU PLAY
Every match counts toward your level, your stats and your title. Board
themes, block styles, typing effects and victory animations unlock as
you play, and a few more come from sharing the game.

Word Wars is free. The optional Premium pack removes the ad break and
adds eight animated boards (Volcano, Space, Clouds,
Forest, Ocean, Cyber, Desert and Aurora), each with its own lettering
on the blocks and keys, plus a few items you can't get any other way.
```

---

## Keywords

> Limit 100 characters, comma-separated, no spaces needed. Words already in the
> app's name or subtitle are wasted here — Apple indexes those anyway.

```
typing,word,spelling,vocabulary,multiplayer,duel,friends,letters,puzzle,brain,versus,daily,wordplay
```

*(99 characters.)* Swapped **anagram** and **race** for **friends** and
**daily**: the game is not an anagram game, and a search for one lands a player
who is looking for something else; *friends* and *daily* are what it now leads
with.

---

## Promotional Text

Already in `RELEASE-0.51.1.md`; repeated here so the listing is in one place.

```
Invite a friend with a link and play in seconds. The keyboard learns your aim, and eight animated Premium boards are waiting: lava, northern lights, a neon street and more.
```

---

## What changed from the 1.5.1 description, and why

- **Voice.** Rewritten after the first promo video drew "this looks AI" comments.
  No em dashes, no "you are not X, you are Y" lines, contractions where a person
  would use them, and the worked FRIENDSHIP → SHIP → MENT example up front,
  because it explains the game faster than any sentence about it.

- **Versus.** It said "over Game Center … text an invite to any contact". 1.5.5
  runs versus on Epic Online Services with invite links and room codes; Game
  Center is no longer how you play someone.
- **Daily is 75 seconds**, not sixty (`DAILY_SECONDS` in `scripts/game.gd`).
- **The lesson is five steps**, not seven (`STEPS` in `scripts/tutorial.gd`).
- **Seven CPU rivals**, not the four the old copy named (`ROSTER` in
  `scripts/ai_opponent.gd`); the copy still names four as examples.
- **Survival and Weekly** were missing entirely.
- **The keyboard** section is new with 1.5.5.
- **The Premium pack** now names its eight boards. Guideline 2.3.2 wants paid
  content identified, and the screenshots and preview both feature these boards,
  so the description says plainly which ones are in the pack.

## Facts this copy states, and where to check them

| Claim | Source |
|---|---|
| 75-second daily | `DAILY_SECONDS := 75.0`, scripts/game.gd |
| five-step lesson | `STEPS`, scripts/tutorial.gd (5 entries) |
| up to three CPU rivals | `SLOTS := 4` (you plus three), scripts/game.gd |
| seven CPU personalities | `ROSTER`, scripts/ai_opponent.gd |
| four weekly missions | `PER_WEEK := 4`, scripts/missions.gd |
| ~350,000 words | `WordBank` at boot: "349751 valid" |
| Scrabble letter values | scripts/scoring.gd header |
| five-character room codes | `CODE_LENGTH := 5`, scripts/eos_config.gd |
| eight animated boards in Premium, each with its own font | the `buy: PACK_PREMIUM` theme rows, scripts/profile.gd |
| cosmetics from sharing | the `shares` rows, scripts/profile.gd |
