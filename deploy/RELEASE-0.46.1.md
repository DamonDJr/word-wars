# Word Wars 0.46.1 (build 1) — App Store review copy

Three blocks below. The first goes in **App Review Information → Notes**, the
second in **What's New in This Version**, the third in **Promotional Text**.

`0.46.1` is this repository's build track. The intended App Store marketing
version for this submission is **1.4.1**.

**The two numbers are different on purpose and always have been.** The listing
runs on `1.x.y` and the binary runs on `0.4x.y`, and Apple's ordering check
applies to the binary: the rejection that produced `RELEASE-0.45.0.md`'s version
note named the previously approved version as `0.43.0`, not `1.3.0`. So the rule
to check before submitting is `CFBundleShortVersionString` against the last
*approved binary*, which was `0.45.0`. `0.46.1` clears it. Nothing needs
renumbering.

## What this release covers

`1.4.0` is `READY_FOR_SALE` and is what players have. Everything below landed
after it, across `0.46.0 build 1` and `0.46.1 build 1`.

| Shipped in | Change | Kind |
|---|---|---|
| 0.46.0 build 1 | iPad keyboard sized for an iPad | fix |
| 0.46.0 build 1 | Menus can be scrolled | fix |
| 0.46.0 build 1 | Daily runs 75 seconds | change |
| 0.46.0 build 1 | An ad break at the end of the daily | change |
| 0.46.0 build 1 | A third daily reminder, and an earlier first one | change |
| 0.46.1 build 1 | Challenges appear at all | fix |
| 0.46.1 build 1 | A spent daily answers a challenge on its own | change |

**Two of these undo something `1.4.0` announced.** Its What's New sold the
phone-sized iPad keyboard as a deliberate fairness decision, and sold challenges
that "actually start". The first was wrong and is reversed; the second could
never have worked, because the game was reading the wrong GameKit challenge
store. The copy below owns both rather than quietly moving on, which is the
right call for an update whose whole content is things that were broken.

---

## App Review Notes

> Paste into App Store Connect → App Review Information → Notes. Limit is
> 4,000 characters.

```
THIS IS A BUG-FIX UPDATE. No new features, no new permissions, no
change to the purchase, the advertising SDK, the data collected, or the
user-generated content answers given at the last review.

WHAT CHANGED

1. THE IPAD KEYBOARD. The previous version laid the on-screen keyboard
   out in points, so keys were the same physical size on an iPad as on
   an iPhone. On a tablet that produced a phone-sized keyboard adrift in
   the middle of the screen, with keys about a third the width of the
   system keyboard on the same device. Both layouts, split and full, are
   now sized as a proportion of the screen and fill the iPad.

   Assessable immediately on any iPad, signed out, in Practice. The
   "Split keyboard" switch in SETTINGS toggles the two layouts.

2. MENU SCROLLING. Menu buttons activated on finger-down. Because these
   menus are full-width buttons top to bottom, there was nowhere a scroll
   gesture could begin, so dragging opened whatever was under the finger.
   Buttons now activate on finger-up, and only if the finger comes up on
   the same button it went down on.

   Assessable immediately on an iPhone, signed out, on the title screen.

3. CHALLENGES. GameKit has two challenge systems. The legacy one
   (GKChallenge) is a player-to-player score challenge with no App Store
   Connect configuration. The current one is a challenge definition
   configured in App Store Connect, which is what this app has, and it
   arrives through GKChallengeDefinition. The app was reading only the
   first, so challenges issued against our definitions were invisible to
   it. It reads both now.

   NEEDS A SECOND GAME CENTER ACCOUNT. With no challenge running, no
   row is drawn — that is the expected state, not a failure.

4. THE DAILY RUN is 75 seconds instead of 60, with the difficulty ramp
   stretched to match.

5. AN AD BREAK AT THE END OF THE DAILY. Worth naming because it is a
   monetization change rather than a fix. The daily previously showed no
   advert at all. It now takes the same break every other mode takes,
   after the run, over the game's own AD BREAK curtain, subject to the
   same frequency budget — for a player who only plays the daily that is
   roughly one break every few days, not one per run. Removed entirely by
   the existing Premium pack.

6. LOCAL NOTIFICATIONS. Unchanged in kind and in permission handling.
   There is now a third: the daily board still unplayed at 1pm. All three
   are about the same object, today's board, and are cancelled the moment
   it is played. Still opt-in, still asked for after a daily run rather
   than at launch, still nothing sent to a player with nothing waiting,
   and still no re-engagement messaging.

ASSESSING IT ON ONE DEVICE, SIGNED OUT

Unchanged from the last review. Practice, Daily, Survival and Solo are
fully playable with no account and no network, on iPhone and on iPad.
VERSUS opens our lobby and CPU Match works with no account. BOARDS is
reachable and explains itself when signed out.

USER-GENERATED CONTENT, THE PURCHASE, ADVERTS AND CLOUD SAVE

All unchanged from the last review except the daily ad break named above.
There is no field anywhere in this app where a player types a name
another player can see. Typing input accepts a to z only and is checked
against a fixed dictionary. Leaderboards show Game Center display names,
sourced from Game Center and drawn through the game's profanity filter.
Blocking and reporting are handled by Game Center. The single in-app
purchase, Premium pack, removes adverts and unlocks three cosmetics;
RESTORE PURCHASES is in SETTINGS whether or not it is owned. Progress is
backed up with Apple's Game Center saved games into the player's own
iCloud account. No server of ours is involved anywhere in this app.
```

---

## What's New in This Version

> Paste into App Store Connect → What's New in This Version. Limit is 4,000
> characters.

```
THE IPAD KEYBOARD IS AN IPAD KEYBOARD NOW

The last update gave the iPad a keyboard built to phone measurements, on
the reasoning that bigger keys on a bigger screen would be a quiet
advantage in a game scored by words per minute. That was the wrong call,
and it was wrong in a way you could feel: a phone keyboard stranded in
the middle of a foot of glass, with keys about a third the width of the
ones iOS puts on the same device. The split layout came off worst, since
the whole point of it is two halves far enough apart to need two thumbs.

Both layouts fill the iPad now.

MENUS YOU CAN ACTUALLY SCROLL

Every menu in this game is wall-to-wall buttons, which left nowhere for a
scroll to begin — a finger dragging down the title screen opened whatever
it landed on instead. Buttons wait for your finger to come back up now,
and sliding off one cancels it, which is what every other button on your
phone already does.

CHALLENGES TURN UP

Game Center has two challenge systems and this game was reading the one
yours do not arrive in. So a challenge sent to you notified you, and then
appeared nowhere in the game. It sits on the title screen now, above
everything else, and one tap takes you to the board it is scored on.

And if you have already used today's daily run when a challenge lands,
your score goes to it on its own. No more being told to come back at
midnight for a race that would have finished by then.

A LONGER DAILY

Seventy-five seconds instead of sixty. A minute was not quite enough to
dig out of the opening pile and still have a run left to play, so the
clock is longer and the board leans on you at the same pace it always
did, spread over the extra time rather than stacked on the end of it.

MORE OF A REMINDER, IF YOU ASKED FOR ONE

The morning reminder moved an hour earlier, and there is a lunchtime one
for a board still sitting unplayed. Still opt-in, still nothing at all
unless there is something of yours waiting.
```

---

## Promotional Text

> Paste into App Store Connect → Promotional Text. Limit is 170 characters.
> Changeable without shipping a build, so it carries whatever is newest.

```
A real keyboard on iPad, menus that scroll, and challenges that finally turn up where you can see them. The daily run is seventy-five seconds now.
```

*(147 characters.)*

---

## Screenshots

**The iPad set has to be regenerated and re-uploaded.** It is the one asset this
release invalidates: every tablet screenshot on the listing shows the old
phone-sized keyboard, which is the exact thing this update fixes, and leaving
them up advertises the bug.

```bash
tools/shots.sh --appstore
```

That writes `build/shots/appstore`. Upload the plain files as iPhone 6.9" and
the `-ipad` files as iPad 13". The iPhone set is unchanged by this release and
does not strictly need re-uploading, but it is rendered by the same command and
re-uploading it costs nothing.

---

## Notes for the next person

**The two version tracks are not a mistake.** See the note at the top. The
listing is `1.x.y`, the binary is `0.4x.y`, and Apple's higher-version check is
against the last approved *binary*. Checking the wrong one wastes an afternoon;
`asc versions list --app 6802900966` shows the listing track and
`asc builds pre-release-version view --app 6802900966 --latest` shows the binary.

**The daily ad break is in the review notes and not in What's New.** That
follows the last three releases, which kept ad cadence out of player-facing
copy — but those were changes to how often an existing break fired, and this one
puts a break in a mode that had none. If it is going to be mentioned to players
at all, this is the release to do it in.

**There are two GameKit challenge systems.** This is now written up properly in
`docs/game-center-setup.md` §2b. The short version: definitions configured in
App Store Connect arrive through `GKChallengeDefinition`, not through
`GKChallenge.load_received_challenges`, and the second returns an empty array
forever on a modern device. `Boards.why_no_challenges()` is surfaced under the
Challenges button on the BOARDS screen and distinguishes every cause.

**A definition-backed challenge has no target score and no issuer.** The API
does not carry either — `GKLeaderboardEntry` has a score and a rank and no
identifier of the board it came off. So there is no "beat Anna's 12,400" and no
beaten/missed verdict on the summary or share card for one. The legacy reader is
kept for the case where a classic challenge arrives, because that one does carry
both. If Apple ever exposes the target, `_running_challenge_sub` and
`_challenge_verdict` are the two places to look.

**`has_active_challenges` is assumed to be per-player.** It answers a bare bool
and the wrapper's docs do not say whose. If the challenge row ever appears for
somebody who has not been challenged, that assumption is why.

**The landscape title screen still overflows.** `_screen_laid()` exceeds the
720 viewport and `_scrollable()` is false in landscape, so the bottom rows are
unreachable. Still not an iOS problem — the app is portrait-locked — but still
live on the desktop builds, and the challenge row makes it one row worse.

**`cloudtest` has three pre-existing failures** around what the cloud row says
after a restore. Unrelated to this release and confirmed present before any of
it; worth fixing before it hides a real one.
