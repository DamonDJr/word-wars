# Word Wars 0.45.0 (build 1) — App Store review copy

Three blocks below. The first goes in **App Review Information → Notes**, the
second in **What's New in This Version**, the third in **Promotional Text**.

`0.45.0` is this repository's build track. The intended App Store marketing
version for this submission is **1.4.0**. **Read the version note below before
submitting — the build already uploaded carries `0.45.0`, not `1.4.0`.**

## What this release actually covers

More than it looks like, and this is the thing to get right.

`RELEASE-0.43.0.md` was written for **build 3**. Builds 4, 5 and 6 went out
after that copy was written, and build 6 is what Apple approved and released.
So three finished features are already in players' hands and have never been
announced:

| Shipped in | Feature | Announced? |
|---|---|---|
| 0.43.0 build 4 | The versus lobby | no |
| 0.43.0 build 5 | Sharing a result | no |
| 0.43.0 build 6 | Streak reminders and the rating prompt | no |
| 0.45.0 build 1 | iPad, challenges that start, the rebuilt share card | new |

This is the same situation `0.42.4` was in with achievements, and it is worth
knowing for the same reason: most of the code being announced here has been
sitting in players' hands doing nothing they could see.

**iPad is the biggest item and is not on the list you were working from.** It is
a new device family on the listing, it needs its own screenshots, and it is the
thing a reviewer will physically be holding.

---

## App Review Notes

> Paste into App Store Connect → App Review Information → Notes. Limit is
> 4,000 characters; this is 3,977, so anything added here needs something
> else cut.

```
WHAT IS NEW IN THIS BUILD

Five things. Three can be assessed on one device with no account. One
needs a Game Center account, and one needs a second person as well.

1. IPAD. The app previously ran on iPad as a stretched iPhone build. It
   is a native iPad layout now, targeting both device families. The
   on-screen keyboard is specified in points rather than as a fraction of
   the screen, so keys are the same physical size as on a phone, and on a
   tablet it splits into two halves at the left and right edges so both
   thumbs can reach. SETTINGS has a "Split keyboard" switch to turn that
   off.

   Assessable immediately on any iPad, signed out, in Practice.

2. VERSUS OPENS OUR OWN LOBBY, with three doors: Quick Match, Invite a
   friend (Apple's sheet in invite-only mode, which texts a link to any
   contact), and CPU Match.

   CPU MATCH IS ALWAYS AVAILABLE AND NEEDS NO ACCOUNT. This matters for
   review: with nobody else queued it is the one door that opens, and it
   is offered on arrival rather than after a failed search. Twenty
   seconds into a search finding nobody, it says so and highlights
   itself.

3. SHARING A RESULT. Every end-of-match summary has a Share door. It
   composes a 1080x1920 PNG from the match's own numbers, writes it
   inside the app's container, and hands it to the standard iOS share
   sheet with a sentence and our App Store link. It is not a screenshot
   and captures nothing outside the app. No account needed.

4. CHALLENGES CAN BE STARTED FROM THE GAME. Challenges are Apple's
   feature running on our two leaderboards. Accepting one used to leave
   the player on our menu with nothing to press, because GameKit does not
   tell an app when its Start button is used. The title screen now offers
   whatever is waiting as a door of its own, naming the sender and the
   score to beat, and starts the matching mode.

   NEEDS A SECOND GAME CENTER ACCOUNT — a challenge is a race between two
   people. With none waiting the door is not drawn: that is the expected
   state, not a failure.

5. STREAK REMINDERS. Two local notifications — the daily board rolling
   over, and a daily streak about to lapse. Opt-in, and permission is
   asked after the first daily run rather than at launch. Nothing is sent
   to a player with no streak, and there is no re-engagement messaging.

A PRIVACY FIX WORTH NAMING

In a live two-device match, the letters an opponent was part way through
typing were sent in every state packet and shown on their board. That was
never deliberate. Letters in flight are now local and are not sent.

USER-GENERATED CONTENT IS UNCHANGED FROM THE LAST REVIEW

The leaderboard lists Game Center display names beside scores, drawn
through the same profanity filter the game uses for names and sourced
from Game Center rather than from any system of ours. There is no field
anywhere in this app where a player types a name another player can see.
Typing input accepts a to z only and is checked against a fixed
dictionary. Blocking and reporting are handled by Game Center.

ASSESSING IT ON ONE DEVICE, SIGNED OUT

Practice, Daily, Survival and Solo are fully playable with no account and
no network, on iPhone and on iPad. VERSUS opens the lobby and CPU Match
works. BOARDS is reachable and explains itself when signed out.

ADVERTS, THE PURCHASE AND CLOUD SAVE

All unchanged. The free version shows an occasional full-screen
interstitial between matches, served by Google AdMob, announced by the
game's own AD BREAK curtain first. The single in-app purchase, Premium
pack, removes that break and unlocks three cosmetics that cannot be
earned; RESTORE PURCHASES is in SETTINGS whether or not it is owned.
Progress is backed up with Apple's Game Center saved games into the
player's own iCloud account. No server of ours is involved anywhere in
this app, and the backup carries no name, email address, contacts or
location. The privacy policy at the support URL covers it under "Cloud
saves".
```

---

## What's New in This Version

> Paste into App Store Connect → What's New in This Version. Limit is 4,000
> characters; this is 2,273.

```
IT PLAYS ON IPAD NOW

Properly, rather than as a phone app pulled to fit. The keyboard is built
in real measurements instead of as a share of the screen, so the keys are
the size your thumbs already know — no bigger on a tablet, which would
have been a quiet advantage on a game scored by words per minute. On an
iPad it splits into two halves at the edges, because the middle of a
foot-wide keyboard is not somewhere a thumb goes. There is a switch in
Settings if you would rather set it down and use all ten fingers.

The room that frees up goes to your opponents' boards, which a portrait
screen has never had space to show you before.

VERSUS HAS A ROOM OF ITS OWN

Tapping VERSUS used to hand you straight to Apple's matchmaking screen,
which takes over and, on a quiet evening, finds nobody. There is a lobby
now with three doors: find anyone playing right now, text an invite to
anyone in your contacts, or take on the CPU.

The CPU door is always open. It is not a consolation prize behind a
failed search — it is there from the moment you walk in, and if a search
has been running twenty seconds without finding anyone, it says so.

SEND SOMEBODY YOUR RESULT

Every summary has a Share door: survival, the daily, solo and versus. It
builds a card from the run — the score, the clock, the badge for what
you actually did, and the best word you played, drawn as the blocks you
played it against.

Then it asks the person you sent it to a question with your number in it.
That is the whole point of sending one.

CHALLENGES THAT ACTUALLY START

Race a friend on the Daily or Survival board and the challenge now waits
for you on the title screen, above everything else, with their name on it
and the score to beat. One tap starts the right mode. The end screen tells
you whether you took it, and by how much.

DON'T DROP THE STREAK

Two reminders, and only two: the daily board rolling over, and a streak
you are about to lose. Nothing else, nothing if you have no streak, and
nothing at all unless you ask for it.

AND ONE FIX WORTH SAYING OUT LOUD

In a live match against another person, the letters you were part way
through typing were being sent to them and lit up on their board. That
was never meant to happen. What you are typing is yours until you fire it.
```

---

## Promotional Text

> Paste into App Store Connect → Promotional Text. Limit is 170 characters.
> Unlike the description, this can be changed without shipping a build, so it
> is the place to put whatever is newest.

```
Now on iPad, with a keyboard built for thumbs. Share your best runs, race friends on the daily board, and take on the CPU any time the lobby is quiet.
```

*(150 characters.)*

---

## Notes for the next person

**The marketing version and the binary have to agree, and right now they do
not.** `0.45.0 build 1` is uploaded and in App Store Connect. Apple's own
rejection of `0.43.0 build 7` is the evidence for what it will accept:

```
90062  CFBundleShortVersionString [0.43.0] must contain a higher version
       than that of the previously approved version [0.43.0]
```

Apple names the previously approved version as **0.43.0**, not 1.3.0 — so the
released train is the `0.4x.x` numbering, whatever the listing is thought of as.
Submitting this as **1.4.0** means the binary has to carry `1.4.0`, which means
bumping `config/version` in `project.godot` and both `application/short_version`
entries in `export_presets.cfg`, then shipping a new build. `1.4.0` is a higher
version than `0.45.0` (Apple compares component by component, so `1 > 0`), so
the jump itself is fine — the uploaded build simply is not the one to submit.

**iPad needs its own screenshots.** A new device family will not pass submission
on the iPhone set. `tools/shots.gd --ipad` renders the tablet layout at
1001x1440 without an iPad, and `--fullkeys` renders it with the split keyboard
turned off, which is the other half of the setting and the one nobody would
otherwise look at.

**Challenges are approved separately from the app.** They are configured at the
app level and go through their own submission, so this build can ship with the
title-screen door never appearing if that approval has not landed. It is drawn
only when a challenge is actually waiting, so its absence looks identical to
everything being fine.

**A challenge on a leaderboard this build does not know is ignored on purpose.**
Only `com.damonj.wordwars.daily` and `com.damonj.wordwars.survival` map to a
mode. A challenge configured against any other id is dropped rather than opening
a guessed-at mode — so if the door never appears with a challenge definitely
waiting, check which board it was configured against before suspecting the code.

**Apple never tells the app that Start was pressed.**
`player(_:wantsToPlay:)` is the GameKit callback for it and the plugin does not
bridge it — `GKLocalPlayer` exposes only `challenge_received`,
`challenge_completed` and the two `other_player` signals. The title-screen door
exists because that callback does not. If the plugin ever adds it, the door can
become an automatic start and this note is where to look first.

**The landscape title screen overflows.** `_screen_laid()` returns 858 against a
720 viewport and `_scrollable()` is false in landscape, so the bottom rows are
unreachable. It does not affect iOS — `window/handheld/orientation=1` is
portrait-locked — but it is live on the desktop builds and predates the
challenge door, which adds 54 to it.

**Ad frequency is still every two to three matches**, as it has been since
`0.39.0`. Not in What's New, for the same reason as the last two releases.
