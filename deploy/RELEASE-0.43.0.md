# Word Wars 0.43.0 (build 3) — App Store review copy

Three blocks below. The first goes in **App Review Information → Notes**, the
second in **What's New in This Version**, the third in **Promotional Text**.

`0.43.0` is this repository's build track. In App Store Connect this is
version **1.3.0**, sitting in `PREPARE_FOR_SUBMISSION`. The last version
actually on sale is **1.2.0**, which was the `0.42.4` track — so unlike the
previous release, What's New has one version to cover rather than six.

**The three Game Center features in this release are the ones the last one
could not talk about.** `0.42.4` shipped all seventeen achievements in the
binary and deliberately said nothing about them, because the ids did not exist
in App Store Connect and Apple refuses the whole batch when one is missing.
Those ids, their artwork, and the two challenges are now configured. That is
what makes this release announceable, and it is worth knowing that most of the
code has been sitting in players' hands doing nothing for a version.

---

## App Review Notes

> Paste into App Store Connect → App Review Information → Notes.

```
WHAT IS NEW IN THIS BUILD

Three things, and two of them need a Game Center account to see.

1. LEADERBOARDS, a new screen. Tap BOARDS on the title screen. It shows
   the Daily and Survival boards, global or friends, with your own
   placing and what the next place up would cost you. Signed out, the
   screen says "sign in to Game Center to see this board" — that is the
   expected state and not a failure.

2. ACHIEVEMENTS AND CHALLENGES. Seventeen achievements have been in the
   binary since the previous version but were inert, because the
   identifiers did not exist on our side in App Store Connect. They are
   configured now, so they report and unlock normally. Challenges are
   Apple's own feature built on our two leaderboards and are reached
   through the Game Center dashboard, from the button on the BOARDS
   screen.

3. The end-of-match summary and the new leaderboard screen were both
   rebuilt for a phone. Type is larger, the result fills the screen
   rather than the top third of it, and a lost match now says by how
   much. Visible immediately in any match against the CPU.

OTHER PLAYERS' NAMES NOW APPEAR IN THE APP

This is the one change that affects what is displayed to a user. The
leaderboard screen lists Game Center display names beside their scores.
They are drawn through the same profanity filter the game already used
for names, and they come from Game Center rather than from any system of
ours — there is no field anywhere in this app where a player types a name
that another player can see. Blocking and reporting are handled by Game
Center itself.

Everything else about user-generated content is unchanged: typing input
accepts a to z only and is checked against a fixed dictionary.

ASSESSING IT ON ONE DEVICE, SIGNED OUT

Every mode except VERSUS is fully playable with no account and no network:
Practice, Daily, Survival and Solo. The BOARDS screen is reachable and
explains itself when signed out. Achievements and challenges cannot be
exercised without a Game Center account, and challenges additionally need
a second person — they are a race between players.

MULTIPLAYER STILL NEEDS A SECOND PERSON

Tapping VERSUS opens Apple's standard Game Center matchmaking screen
(GKMatchmakerViewController), offering Quick Match and Invite Friends.
With one device and nobody else queued, Quick Match will wait and find
nobody. Emotes are only reachable in a live two-device match.

ADVERTS AND THE PURCHASE

The free version shows an occasional full-screen interstitial between
matches, served by Google AdMob, announced by the game's own AD BREAK
curtain first. The single in-app purchase, Premium pack, removes that
break and unlocks three cosmetics that cannot be earned. RESTORE
PURCHASES is in SETTINGS and is reachable whether or not the pack is
owned.

CLOUD SAVE

Unchanged from the previous version. Progress is backed up with Apple's
Game Center saved games into the player's own iCloud account. There is no
server of ours involved anywhere in this app, and the backup carries no
name, no email address, no contacts and no location. The privacy policy
at the support URL covers it under "Cloud saves".
```

---

## What's New in This Version

> Paste into App Store Connect → What's New in This Version. Limit is 4,000
> characters; this is well under.

```
LEADERBOARDS, IN THE GAME

There is a board to be on now, and a screen to see it on. BOARDS shows
the Daily and Survival leaderboards — everyone, or just your friends —
with your own placing picked out of it.

It also tells you what the next place up is worth. Not a rank, which is
only a verdict, but the gap: the points between you and the player one
line above. On a busy day that is usually a single good word.

ACHIEVEMENTS

Seventeen of them, from your first win to a hundred matches, and they
work now. Break four blocks with one word, hold an eight-link chain, type
a twelve-letter word, win without losing a life. Each one has a title
attached that you can wear on the mastery screen.

CHALLENGES

Pick somebody and race them on a board for a day, three days or a week.
Game Center tells you when they take your place, and tells them when you
take it back.

WINNING LOOKS LIKE WINNING

The end-of-match screen was built for a desktop window and arrived on
your phone squashed into the top third of it. It uses the whole screen
now, the type is large enough to read at arm's length, and a win gets a
celebration instead of a word in gold.

A loss tells you the margin. Being beaten by four hundred points and
being beaten by forty thousand are different evenings, and only one of
them is worth a rematch — so the screen says which it was, and puts the
rematch button under your thumb.

AND THE SCOREBOARD AGREES WITH THE RESULT

You could win a match and still finish second on points. Taking the match
is worth a great deal more than it was, and winning now doubles what your
attacks were worth, so the player who won is the player at the top of the
table.

Speed Demon now asks for 50 words per minute rather than 65. The old
number was set on a full-size keyboard and was never a fair ask of a
thumb.
```

---

## Promotional Text

> Paste into App Store Connect → Promotional Text. Limit is 170 characters.
> Unlike the description, this can be changed without shipping a build, so it
> is the place to put whatever is newest.

```
New: leaderboards, seventeen achievements, and challenges. See where you stand, then see what the next place up would cost you — usually one good word.
```

---

## Notes for the next person

**Check the leaderboard screen on a signed-in device before submitting.** It is
the headline of this release and it is the one screen whose content comes
entirely from Apple. `docs/game-center-setup.md` has a table of what each empty
state means; the one to worry about is **"this board is not set up yet"**, which
means an id is missing or misspelled in App Store Connect rather than anything
being wrong with the build.

**Challenges need review approval separately from the app.** They are
configured at the app level and go through their own submission, so a build can
ship with the challenge button leading to an empty dashboard if that approval
has not landed. `Boards.challenges_available()` gates the button on the API
being present, not on a challenge existing, so it will be drawn either way.

**The achievement artwork is 1024x1024 now.** Apple's requirement moved from
512; the originals are in Nextcloud under `AchievementIcons/` and the converted
set beside it in `AchievementIcons1024/`. They were upscaled rather than
re-rendered, because no vector sources exist. If any of them are ever redrawn,
draw them at 1024 and keep the sources this time.

**Speed Demon is 50 because the icon says 50.** The car in
`AchievementIcons_007.png` carries the number on its door, so the threshold was
moved to the art rather than the art to the threshold. If the description in
App Store Connect still reads "Reach 65 words per minute", it is stale — the
code pays at 50.

**The scoring change does not touch Daily or Survival.** Both are gated to
`Mode.NORMAL`, deliberately: the survival board is all-time, and inflating
scores there would have undercut every score already posted. Anything that
raises match scores in future needs the same care, or the leaderboard stops
comparing like with like.

**Ad frequency is still every two to three matches**, as it has been since
`0.39.0`. Not in What's New for the same reason as last time — nobody announces
more adverts — but it remains the change most likely to show up in reviews.
