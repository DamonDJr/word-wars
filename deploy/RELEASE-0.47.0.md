# Word Wars 0.47.0 (build 2) — App Store review copy

Three blocks below. The first goes in **App Review Information → Notes**, the
second in **What's New in This Version**, the third in **Promotional Text**.

`0.47.0` is this repository's build track. The intended App Store marketing
version for this submission is **1.4.7**.

**The two numbers are different on purpose.** The listing runs on `1.x.y` and the
binary on `0.4x.y`, and Apple's higher-version check applies to the binary. The
last approved binary is `0.46.1`, which shipped as listing version **1.4.5**;
`0.47.0` clears it. Check both before submitting rather than trusting either:

```bash
asc versions list --app 6802900966
asc builds pre-release-version view --app 6802900966 --latest
```

## What this release covers

`1.4.5` is `READY_FOR_SALE` and is what players have. Everything below landed
after it, in `0.47.0 build 2`.

| Change | Kind |
|---|---|
| Both players' summaries now show the same scores | fix |
| Invite no longer behaves like Quick Match | fix |
| A first-word prompt on the board | new |
| The tutorial is five steps instead of seven | new |
| Emotes on the versus summary | new |
| Score payouts no longer overlap each other | fix |

**Build 2 is build 1 plus the last of those.** Two scoring events inside the same
moment — a strike and the salvo it completed — were drawn at the same height and
became one unreadable number. It was found while recording the App Preview,
where it is on screen for most of twenty seconds, but it happens to everybody in
ordinary play. Build 1 was never submitted, so the version is unchanged.

**Two of these come out of the same problem, which is worth naming because it
shapes the copy.** Players were waiting for a block with letters on it before
typing anything — a rule nobody taught them and the game never contradicted.
That is a third of the game played at a third of the speed, and it is why the
prompt and the shortened tutorial are in the same release.

---

## App Review Notes

> Paste into App Store Connect → App Review Information → Notes. Limit is
> 4,000 characters.

```
No new permissions, no change to the purchase, the advertising SDK, the
data collected, or the user-generated content answers given at the last
review.

WHAT CHANGED

1. TWO BUG FIXES IN NETWORKED PLAY. At the end of a two-player match the
   two devices could print different final scores for the same match. The
   damage a player had dealt was credited only on the device the words
   were typed on and was never sent, so one term of the end-of-match
   bonus was computed from zero on the opponent's phone. Each device now
   sends its own finished score at the whistle and the other displays it
   as received.

   Separately, the Invite door set the app into a "searching" state
   before Apple's matchmaking sheet was confirmed on screen, so a sheet
   that failed to appear looked identical to a quick match in progress
   with no way out. The app now stays idle until Game Center reports
   something.

   BOTH NEED TWO GAME CENTER ACCOUNTS to observe.

2. A PROMPT ON THE BOARD. New players were waiting for blocks to appear
   before typing, which is not how the game works — any word may be typed
   at any time. A faded line now reads "TYPE ANY WORD / you do not have
   to wait for blocks" across the middle of the board at the start of a
   match, and disappears as soon as a word is typed.

   Assessable immediately on any device, signed out, in Practice.

3. THE TUTORIAL IS SHORTER. Seven steps to five. The two removed asked
   for a six-letter word and for three words typed inside a few seconds
   of each other, which are a vocabulary test and a typing-speed test
   rather than explanations. The card now sits over the middle of the
   board, and the final step offers a button to run the lesson again.

   Assessable immediately, signed out: PRACTICE then the lesson.

4. EMOTES ON THE END-OF-MATCH SCREEN. The same fixed set of seven
   cartoon characters already available during a two-player match is now
   offered as a row along the bottom of the versus summary. Tapping one
   sends it to the opponent; it is displayed at a larger size with the
   sender's Game Center display name above it and plays three times
   before fading.

   THIS IS A FIXED SET, NOT USER-GENERATED CONTENT. There is no free
   text anywhere in it. The seven are drawn by us and ship inside the
   binary; a player chooses one of seven, and an index number is what
   crosses the network. A rate limit prevents one being sent more than
   once every 2.5 seconds. The name shown is the Game Center display
   name, sourced from Game Center, which is the same name already shown
   on the leaderboards and in the match itself.

   NEEDS TWO GAME CENTER ACCOUNTS to send between, though the row itself
   is visible at the end of any two-player match.

ASSESSING IT ON ONE DEVICE, SIGNED OUT

Unchanged. Practice, Daily, Survival and Solo are fully playable with no
account and no network, on iPhone and on iPad. VERSUS opens our lobby and
CPU Match works with no account. BOARDS is reachable and explains itself
when signed out.

USER-GENERATED CONTENT, THE PURCHASE, ADVERTS AND CLOUD SAVE

All unchanged from the last review. There is no field anywhere in this
app where a player types a name another player can see. Typing input
accepts a to z only and is checked against a fixed dictionary.
Leaderboards show Game Center display names, sourced from Game Center and
drawn through the game's profanity filter. Blocking and reporting are
handled by Game Center. The single in-app purchase, Premium pack, removes
adverts and unlocks three cosmetics; RESTORE PURCHASES is in SETTINGS
whether or not it is owned. Progress is backed up with Apple's Game
Center saved games into the player's own iCloud account. No server of
ours is involved anywhere in this app.
```

---

## What's New in This Version

> Paste into App Store Connect → What's New in This Version. Limit is 4,000
> characters.

```
YOU DO NOT HAVE TO WAIT FOR BLOCKS

It turns out a lot of people were, and it is hard to blame them: the
board is the only thing on screen with letters on it, so the board looks
like the input. It is not. Every word in the dictionary is available from
the first second, blocks or no blocks, and typing constantly is the whole
game rather than an advanced technique.

Nothing said so anywhere. Now something does — once, across the middle of
the board, and it goes as soon as you type.

A SHORTER WAY IN

The tutorial was seven steps and two of them were tests rather than
lessons: one wanted a six-letter word, the other wanted three words typed
inside a couple of seconds of each other. Both are things the game
teaches you by itself in about a minute of actually playing it, and both
were where people stopped.

Five steps now. Type a word, see what it does to the other person, answer
what comes back, learn what happens if you let it pile up, and then the
one habit that makes all of it work. The card sits over the board where
you are already looking, and if you want to run it again there is a
button for that on the last screen.

SOMETHING TO SAY AT THE END

Every emote, along the bottom of the versus scoreboard, one tap each.
Whatever you send plays big with your name over its head, three times,
and your opponent gets it on their scoreboard.

Win graciously. Or don't.

AND TWO THINGS THAT WERE BROKEN

At the end of a two-player match, the two of you could be looking at
different final scores for the same game. The winner's phone was right
and the loser's was missing most of the victory bonus. Both phones now
agree, because the numbers are sent rather than guessed at.

Inviting a friend could also drop you into what looked like a quick match
search that never found anybody. The invite screen either opens now or it
does not, and if it does not you get your lobby back instead of a search
that was never running.
```

---

## Promotional Text

> Paste into App Store Connect → Promotional Text. Limit is 170 characters.
> Changeable without shipping a build, so it carries whatever is newest.

```
You never had to wait for blocks — type any word, any time. A shorter way in for new players, emotes on the scoreboard, and two fixed multiplayer bugs.
```

*(150 characters.)*

---

## Screenshots and previews

**Both screenshot sets are regenerated by one command:**

```bash
tools/shots.sh --appstore
```

That writes `build/shots/appstore`. Upload the plain files as iPhone 6.9" and
the `-ipad` files as iPad 13".

**App previews are a separate job and are not produced by that command.** Apple's
accepted sizes are not the ones `tools/record.sh` defaults to, so both have to be
asked for explicitly:

| | Portrait | Length | Frame rate |
|:--|:--|:--|:--|
| iPhone 6.9" | 886 × 1920 | 15–30s | 30fps |
| iPad 13" | 1200 × 1600 | 15–30s | 30fps |

H.264 in .mp4/.mov/.m4v, under 500 MB, stereo AAC. `tools/record.sh --size WxH`
takes the dimensions; the default of 1080x1920 is **not** an accepted App Preview
size and will be rejected on upload.

Two things stand between the current recorder and a submittable pair:

* **`tools/trailer.gd` forces `game.tablet = false`** so the footage looks like a
  phone. An iPad preview needs that lifted — the tablet layout otherwise falls
  out of the viewport shape on its own, because 1200x1600 resolves to a
  1080x1440 design space and that is past `TABLET_RATIO`.
* **The trailer arc is twelve scenes and runs about fifty seconds**, which is
  past Apple's thirty. A preview needs its own shorter scene list rather than a
  crop of that one.

---

## Notes for the next person

**The listing skipped from 1.4.5 to 1.4.7.** That is deliberate and not a typo in
this document; the number was chosen at release time. Nothing in the binary
track skipped anything — `0.46.1` to `0.47.0` is continuous.

**The emote row is the one thing in this release a reviewer might read as UGC.**
It is not, and the review notes say so explicitly and at length, because "players
can now send each other things" is exactly the sentence that attracts a 1.2
rejection. Seven fixed drawings, an index over the wire, no free text anywhere.
If that ever changes — a custom message, a wider set chosen by the player — the
answers on the App Review Information screen have to change with it.

**The daily ad break is still review-notes-only.** It shipped in 0.46.0 and was
flagged there as the first arguable case, since it put a break in a mode that had
none. It has now been through one review without comment.

**`cloudtest` has three pre-existing failures** around what the cloud row says
after a restore. Unrelated to this release and confirmed present before it.

**The tutorial has no opponent board.** The first step says its letters land on
your opponent, and what actually demonstrates that is the block in step two,
stamped with the tail of the word the player just typed. If the lesson is ever
given a real second seat, that step is where the send column would be shown.
