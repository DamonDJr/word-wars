# Word Wars 0.48.0 (build 1) — App Store review copy

Three blocks below. The first goes in **App Review Information → Notes**, the
second in **What's New in This Version**, the third in **Promotional Text**.

`0.48.0` is this repository's build track. The intended App Store marketing
version for this submission is **1.5.0**.

**The two numbers are different on purpose.** The listing runs on `1.x.y` and the
binary on `0.4x.y`, and Apple's higher-version check applies to the binary. The
last approved binary is `0.47.0`, which shipped as listing version **1.4.7**;
`0.48.0` clears it. Check both before submitting rather than trusting either:

```bash
asc versions list --app 6802900966
asc builds pre-release-version view --app 6802900966 --latest
```

**`1.5.0` rather than `1.4.8`, and that is a choice made here.** The last four
listing versions were point releases on top of `1.4`; this one changes what
happens when you leave a run, what the daily summary is a screen about, and how
hard a word hits. A minor bump says that to anybody reading the version history.
Nothing in the binary track skipped anything — `0.47.0` to `0.48.0` is
continuous.

## What this release covers

`1.4.7` is `READY_FOR_SALE` and is what players have. Everything below landed
after it, in `0.48.0 build 1`.

| Change | Kind |
|---|---|
| Leaving a daily now posts the score instead of discarding it | fix |
| A confirmation before walking out of any run worth something | new |
| The daily summary leads with today's global board | new |
| A Game Center invite asks before it abandons your run | new |
| Word length decides block size again, at every chain length | fix |
| A salvo is no longer one stamp repeated | fix |

**Three of these are one bug with three faces.** The daily promises one run a
day and only ever enforced that when the clock ran out. Leaving from the pause
menu banked nothing, so the board could be replayed for a better score;
suspending the app did the same and needed no button; and accepting a Game
Center invite mid-run tore the run down without asking. All three now bank the
score on the way out, through one function.

**The balance change is the one thing here that is a judgement rather than a
fix,** and it is called out in the notes below for that reason. See *Notes for
the next person*.

---

## App Review Notes

> Paste into App Store Connect → App Review Information → Notes. Limit is
> 4,000 characters.

```
No new permissions, no change to the purchase, the advertising SDK, the
data collected, or the user-generated content answers given at the last
review.

WHAT CHANGED

1. LEAVING A RUN NOW ASKS, AND THE DAILY BANKS THE SCORE. The daily
   board is one run a day. Until now that was only enforced when the
   clock ran out: quitting from the pause menu recorded nothing, so the
   same board could be played again for a better score, and closing the
   app mid-run did the same thing.

   Leaving now puts up a confirmation naming what it costs, and for the
   daily it posts the score as it stands and shows the end-of-run summary
   rather than discarding the run. Suspending the app mid-daily banks it
   the same way, silently, with no advert and no dialog.

   Practice and the tutorial leave immediately, recording nothing.

   ASSESSABLE IMMEDIATELY ON ONE DEVICE, SIGNED OUT: DAILY, then pause
   and press Leave.

2. THE DAILY SUMMARY NOW SHOWS TODAY'S LEADERBOARD. The end-of-run
   screen previously ranked the player against their own past runs. It
   now leads with today's Game Center board — other players' ranks,
   display names and scores — with the personal history one tap away on a
   second tab.

   OTHER PLAYERS' NAMES ARE NOT USER-GENERATED CONTENT IN THIS APP. They
   are Game Center display names, sourced from Game Center, drawn through
   the same profanity filter as every other name in the game. This is the
   same data already shown on the BOARDS screen in previous versions; the
   only change is that it also appears on the summary. There is still no
   field anywhere in this app where a player types something another
   player can see.

   Signed out or offline the summary falls back to the personal history
   and draws no tabs. NEEDS A GAME CENTER ACCOUNT to see the global half.

3. A GAME CENTER INVITE NO LONGER ABANDONS YOUR RUN WITHOUT ASKING.
   Accepting an invitation from iOS's own notification banner used to
   close whatever was running on the spot. It now raises a banner inside
   the game naming the sender, with Join and Not now, and only tears the
   run down if Join is pressed. On the title screen, where there is
   nothing to interrupt, it joins immediately as before.

   NEEDS TWO GAME CENTER ACCOUNTS to observe, since an invitation has to
   be sent by somebody.

4. A GAMEPLAY BALANCE CHANGE. The size of the block a word sends now
   depends on the word's length at every point in a match rather than
   only at the start of one, and a long word sends a bigger block than a
   short one throughout. Separately, the ten-block "salvo" awarded for a
   long streak now carries a spread of different letter stamps instead of
   repeating the same one, which had made most of it clearable with a
   single word.

   No new content, no new screens. Assessable immediately in PRACTICE.

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
LEAVING THE DAILY NOW COSTS YOU THE SCORE YOU HAD

One run a day only meant something if the run ended on the clock. Quit
halfway through a bad one and nothing was recorded, so the board was
there to play again — and closing the app did the same thing without even
asking.

Leave now asks first, and tells you what it takes: your score goes to the
board as it stands, and you get the summary for it like any other run.
Close the app mid-run and the same thing happens quietly. The board is
spent either way, which is what one run a day was always supposed to
mean.

Survival and versus ask too, and say what they cost. Practice does not,
because practice costs nothing.

SEE WHERE YOU CAME, NOT JUST HOW YOU DID

The daily summary used to rank you against yourself. That is a fine
thing to know and it is the wrong headline for the one mode where
everybody in the world plays the identical board once. Today's
leaderboard is the first thing you see now — who is above you, what they
scored, and how many points would take the next place off them.

Your own history is still there, one tap away, and still what you get
when you are offline or signed out.

AN INVITE NO LONGER THROWS AWAY WHAT YOU WERE DOING

Tapping a Game Center invitation used to close your run on the spot,
mid-daily, score and all. Now it knocks first: a banner with their name
on it, Join or Not now, and nothing happens to your board until you pick.

LONGER WORDS FINALLY HIT HARDER

They were supposed to already, and from a standing start they did — but
once you had a streak going, the streak decided everything and a
twelve-letter word landed exactly like a three-letter one. Length counts
the whole way through a match now.

And the salvo you get for a long streak stopped arriving as ten copies of
the same block, which one word cleared more than half of. Ten different
ones. Good luck.
```

---

## Promotional Text

> Paste into App Store Connect → Promotional Text. Limit is 170 characters.
> Changeable without shipping a build, so it carries whatever is newest.

```
The daily is one run a day for real now — walk out and your score still posts. See today's whole leaderboard when you finish, and long words finally hit hard.
```

*(158 characters.)*

---

## Screenshots and previews

**No screenshot change is required for this release.** Nothing here alters the
board, the title screen or the versus lobby, which is what the existing sets
show. The daily summary did change and is not in the current set; if it is ever
added, it is the screen most worth adding, because the leaderboard on it is the
one new thing a listing visitor would want to see.

Both sets are still regenerated by one command:

```bash
tools/shots.sh --appstore
```

That writes `build/shots/appstore`. Upload the plain files as iPhone 6.9" and
the `-ipad` files as iPad 13".

**App previews remain outstanding and are unchanged from 0.47.0.** The two
blockers named there both still stand: `tools/trailer.gd` forces
`game.tablet = false` so an iPad preview cannot be recorded without lifting it,
and the trailer arc runs about fifty seconds against Apple's thirty.

| | Portrait | Length | Frame rate |
|:--|:--|:--|:--|
| iPhone 6.9" | 886 × 1920 | 15–30s | 30fps |
| iPad 13" | 1200 × 1600 | 15–30s | 30fps |

---

## Notes for the next person

**The balance change is the one thing in this release that is not a fix.**
Sampled against four thousand words drawn from the game's own bank, an average
word now throws about 24% more block from a standing start and 13–15% more
mid-run. That will shorten matches and raise scores, and it has not been
playtested — there is no match simulator in this repository, and the number was
chosen by measuring candidate ladders rather than by playing. `LENGTH_TIER_AT`
in `scripts/game.gd` is the single knob, and its comment carries the measurement
for the step either side of where it was left. **If matches start ending too
fast, that constant is the first and probably only thing to move.**

**The daily summary is the second screen in this app to draw other people's
names, and the filter was nearly missed.** The BOARDS screen has always run Game
Center display names through `_show_name`; the summary's new peer rows were
drawing them raw when first written, which would have been a new route for an
unfiltered name to reach a player on the screen every daily run ends at.
`blocktest` now asserts it. **Any third screen that lists other players has the
same obligation** — the review notes promise the filter in as many words.

**The invite banner cannot be triggered without a second account,** and no test
covers the real path. `GKInvite` cannot be constructed off an Apple platform, so
`versustest` drives the banner through `game.demo_invite` and covers the layout,
the hit-testing and the decision of who gets asked — but the GameKit half has
never run. Same for the summary's leaderboard, which has only been seen with
injected rows.

**GameKit will not tell you an invitation arrived.** `GKInviteEventListener` has
`didAccept` and `didRequestMatchWithRecipients` and nothing else, so an in-game
banner the moment somebody invites you cannot be built — iOS draws its own and
the first the app hears is that the player already accepted. The banner this
release adds appears after that tap, which is the closest the API allows. Worth
knowing before somebody files it as a bug.

**`cloudtest` has three pre-existing failures** around what the cloud row says
after a restore, and **`survivaltest` has seventeen** around the ad-break budget
and curtain. Both sets were confirmed present before this release and are
unrelated to it.

**The daily ad break is still review-notes-only** and has now been through two
reviews without comment.
