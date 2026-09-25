# Word Wars 0.49.0 (build 4) — App Store review copy

Three blocks below. The first goes in **App Review Information → Notes**, the
second in **What's New in This Version**, the third in **Promotional Text**.

`0.49.0` is this repository's build track. The App Store marketing version for
this submission is **1.5.0**.

**The two numbers are different on purpose.** The listing runs on `1.x.y` and the
binary on `0.4x.y`, and Apple's higher-version check applies to the binary. The
last approved binary is `0.48.0`, which shipped as listing version **1.4.8**;
`0.49.0` clears it. Check both before submitting:

```bash
asc versions list --app 6802900966
asc builds pre-release-version view --app 6802900966 --latest
```

**`RELEASE-0.48.0.md` says it was going out as 1.5.0. It went out as 1.4.8.**
App Store Connect shows 1.4.8 as `READY_FOR_SALE` and has no 1.5.0, so the
number is still free and this release uses it. The old document is left as it
is.

## Which build to submit

**Build 4.** There are four builds against `0.49.0` and only the last one is
complete:

| Build | State |
|---|---|
| 1 | Boards only. No weekly missions, no share rewards. |
| 2 | Adds weeklies and the promo card. Block faces churn while falling. |
| 3 | Fixes the falling churn. Menu block faces still churn. |
| 4 | Everything, both churn bugs fixed. **Submit this one.** |

## What this release covers

`1.4.8` is `READY_FOR_SALE` and is what players have now. Everything below
landed after it, across `0.49.0` builds 1–4.

| Change | Who gets it | Kind |
|---|---|---|
| Eight painted board themes, each with its own animation | Premium pack | new |
| Eight block styles drawn to match them | Premium pack | new |
| Weekly missions — four a week, reset Sunday, paying XP | everyone | new |
| The Nexus board and its block style | 8 share-days | new |
| Waddles, a second character with his own emote set | 15 share-days | new |
| A "Herald" title | 3 share-days | new |
| One-time cards explaining the pack and the share rewards | everyone | new |
| NEW badges on the cosmetics and premium doors | everyone | new |
| Block faces re-randomised their pattern every frame while moving | everyone | fix |

**Eight of the nine new boards are Premium-pack only.** Nexus is the exception
and cannot be bought at all — it is earned by sharing, along with the Herald
title and Waddles. The store copy below says so in both places, because
describing paid content as though it were simply "new" is the kind of thing
that earns a rejection and annoys players who tap through to find a lock.

**No new purchase, no new product, no price change.** The Premium pack is the
same single non-consumable at the same price. It unlocked three cosmetics
before and unlocks nineteen now. Nothing that was free has become paid.

**The share rewards need the review notes read.** They are the first thing in
this app earned by an action taken outside it, so the notes state exactly what
is measured and what is not.

---

## App Review Notes

> Paste into App Store Connect → App Review Information → Notes. Limit is
> 4,000 characters.

```
No new permissions, no new in-app purchase products, no change to the
price, the advertising SDK, the data collected, or the user-generated
content answers given at the last review.

WHAT CHANGED

1. NEW COSMETIC CONTENT IN THE EXISTING PREMIUM PACK. The single
   non-consumable purchase ("Premium pack", com.damonj.wordwars.premium)
   is unchanged in price and identifier. It unlocked three cosmetic
   items before and unlocks nineteen now: eight illustrated board
   backgrounds, eight matching block styles, and the three it already
   had. RESTORE PURCHASES is in SETTINGS whether or not the pack is
   owned. Nothing that was free before is now paid.

   ASSESSABLE ON ONE DEVICE, SIGNED OUT: COSMETICS, then BOARD THEME.
   Locked entries state what they cost.

2. WEEKLY MISSIONS. A new door on the title screen, free to everyone.
   Four objectives are set for the calendar week and reset every Sunday.
   Completing one pays experience points toward the player's level. The
   level is a display number that unlocks cosmetics; it does not affect
   how the game plays.

   The four are chosen by hashing the date of the Sunday that starts the
   week, so every device works out the same four with no network call.
   No server is involved.

   ASSESSABLE ON ONE DEVICE, SIGNED OUT: WEEKLY.

3. REWARDS FOR SHARING THE APP. Three cosmetic items — a title, a board
   theme, and a second character — unlock after the player has used the
   system share sheet on 3, 8 and 15 separate calendar days.

   WHAT IS AND IS NOT MEASURED. Sharing uses UIActivityViewController.
   The app records only that the sheet reported completion, and stores
   only a list of dates in the player's own local save file. It does not
   know, record or transmit where a share went, what was in it, who
   received it, or whether anyone opened it. There is no attribution, no
   tracking, no identifier, no analytics event and no server. At most
   one share counts per calendar day.

   These three cannot be bought. They are the only cosmetics the Premium
   pack does not unlock, and no amount of play reaches them either.

   ASSESSABLE ON ONE DEVICE, SIGNED OUT: COSMETICS, where the locked
   entries state the requirement.

4. A SECOND CHARACTER. "Waddles" is an alternative to the existing
   character for the in-match emote stickers. Cosmetic only. The emotes
   a player can send, and the integer sent over the network, are the
   same for both. Two players running different characters each see
   their own.

5. TWO ONE-TIME CARDS. On first launch after updating, a player without
   the Premium pack sees a card describing it, and a player missing the
   share rewards sees one describing how to earn them. Each shows once
   and never again, never over a match, and both have a visible dismiss
   control. A player who owns everything sees neither.

ASSESSING IT ON ONE DEVICE, SIGNED OUT

Unchanged. Practice, Daily, Weekly, Survival and Solo are fully playable
with no account and no network, on iPhone and on iPad. VERSUS opens our
lobby and CPU Match works with no account. BOARDS is reachable and
explains itself when signed out.

USER-GENERATED CONTENT, THE PURCHASE, ADVERTS AND CLOUD SAVE

All unchanged from the last review. There is no field anywhere in this
app where a player types a name another player can see. Typing input
accepts a to z only and is checked against a fixed dictionary.
Leaderboards show Game Center display names, sourced from Game Center and
drawn through the game's profanity filter. Blocking and reporting are
handled by Game Center. The single in-app purchase removes adverts and
unlocks cosmetics; RESTORE PURCHASES is in SETTINGS whether or not it is
owned. Progress is backed up with Apple's Game Center saved games into
the player's own iCloud account. No server of ours is involved anywhere
in this app.
```

---

## What's New in This Version

> Paste into App Store Connect → What's New in This Version. Limit is 4,000
> characters.

```
EIGHT NEW BOARDS — PREMIUM PACK

A forest with a waterfall. A volcano. The sea floor. Deep space. A neon
city, a sky full of floating islands, a desert at sunset, and an aurora
over a frozen lake.

These are illustrated backgrounds, not recoloured grids, and each one has
something moving in it — leaves coming down, embers going up, light
shifting on the water, a scan line crawling down the city. The whole
screen is the board, keyboard included.

Each comes with a block style drawn for it: cracked lava crust, coral,
neon housing, cut glass, stone, cloud, sandstone, heartwood.

Block colour still means the same thing everywhere. Big blocks are red,
small ones are blue, whatever board you are on and whatever style you
have equipped.

All eight are part of the Premium pack, along with everything it already
unlocked.

WEEKLY MISSIONS — FREE

Four missions a week, the same four for everyone, reset every Sunday.
Type 600 words. Reach a nine-chain. Last five minutes in survival.
Finish them for XP toward your level.

They are worked out from the date, so there is nothing to download and
no connection needed. Your phone and everyone else's arrive at the same
four on their own.

THREE THINGS YOU CANNOT BUY — SHARE TO UNLOCK

Share the game and you earn them. The Premium pack does not include any
of these, and no amount of playing gets them either.

  3 days   the HERALD title
  8 days   the NEXUS board, and the blocks drawn for it
  15 days  WADDLES — an angry duck with his own set of emotes

One share counts per day, so this is a couple of weeks of telling people
about a word game rather than fifteen taps in a row.

FIXED

Board surfaces no longer shimmer while blocks are falling.
```

---

## Promotional Text

> Paste into App Store Connect → Promotional Text. Limit is 170 characters.
> Changeable without shipping a build, so it carries whatever is newest.

```
Eight illustrated boards in the Premium pack, free weekly missions for everyone, and an angry duck you can only unlock by sharing the game.
```

*(138 characters.)*

---

## Screenshots and previews

**A screenshot refresh is worth doing for this release.** The current set shows
the old wash themes on a dark background. None of the nine new boards appear in
it, and they are the most persuasive thing a listing visitor could be shown.

Both sets are regenerated by one command:

```bash
tools/shots.sh --appstore
```

That writes `build/shots/appstore`. Upload the plain files as iPhone 6.9" and
the `-ipad` files as iPad 13".

**`tools/shots.gd` does not set a board theme,** so it renders whatever the
developer profile happens to be wearing. Equip the intended theme first, or use
`tools/boardshots.gd`, which poses every painted board identically at 720×1440.
Those are good frames to crop from but are not at Apple's submission sizes.

**If the screenshots show Premium boards, the listing needs to be clear about
that.** Apple has rejected apps for screenshots that advertise paid content
without saying so. A caption on the affected frames is the usual fix.

**App previews remain outstanding and are unchanged from 0.47.0.** Both blockers
named there still stand: `tools/trailer.gd` forces `game.tablet = false` so an
iPad preview cannot be recorded without lifting it, and the trailer arc runs
about fifty seconds against Apple's thirty.

| | Portrait | Length | Frame rate |
|:--|:--|:--|:--|
| iPhone 6.9" | 886 × 1920 | 15–30s | 30fps |
| iPad 13" | 1200 × 1600 | 15–30s | 30fps |

---

## Notes for the next person

**The weekly XP payout is a guess, not a measurement.** A mission pays 300 XP
and a cleared week is 1,200, against 90 for a match and 240 for a win. Early on
that is about two levels a week; by level 30 it is noise, because the curve is
quadratic. There is no match simulator here, so it has not been tested against
a real progression, and it is live for anyone who installed build 2 or later.
`Missions.MISSION_XP` is the only knob. Lowering it later takes nothing away —
banked XP stays banked — but it does change the rate under people who have got
used to it.

**XP is no longer a pure function of the lifetime record.** Everything else in
`xp_total()` is derived from stats, which is what makes a level recomputable.
A weekly mission cannot work that way: "reach a x7 chain this week" is not
recoverable from a lifetime peak, because the peak does not know which week it
happened in. So `weekly_xp` is banked when earned and added on. It only goes up
and nothing spends it. If another kind of reward ever needs banking, it should
join that field rather than adding a second one.

**The share ladder can be farmed, and the code says so.** iOS reports that the
share sheet completed and nothing else, so someone determined can get all three
rewards in fifteen days of tapping share and cancelling into a note to self.
The one-per-day cap is the only thing between the rewards and being free, and
it is why a day rather than a share is the unit. Closing the hole properly needs
install attribution, which needs a backend.

**The same bug shipped twice.** Block faces seeded their pattern from the
rectangle they were drawn into, which moves every frame while a block falls.
Build 3 fixed the falling case and missed four callers in the menus, which
shipped broken again. The function had a comment asserting the invariant — "a
block does not redraw itself differently every frame" — with nothing enforcing
it. `Blk.art` is the stable key now. Any new caller drawing a face on something
that can move has to pass one.

**Waddles has five animation sets against BloqBot's seven, so two do double
duty.** Victory covers cheer and nice, Exhausted covers cry and dead. The
non-obvious one: "Wait" is not an idle pose, it is arms folded and scowling, so
it took anger. If an angry set and a love set are ever drawn, slots 3 and 4 in
`Cosmetics.CHARACTERS` are the only lines to change.

**Eight of the nine backgrounds are 328×590 and look soft on a phone.** They
were sliced out of a contact sheet, which is what the source art was. Nexus came
in at full size and the difference is obvious side by side. Replacing the eight
is a drop-in: same paths, then `godot --headless --import`. Worth doing before
the screenshot refresh, or the soft versions are what ends up on the listing.

**`cloudtest` has three pre-existing failures** around what the cloud row says
after a restore, and **`survivaltest` has seventeen** around the ad-break budget
and curtain. Both were confirmed present before this release. The `survivaltest`
seventeen are an artefact of the development profile owning the Premium pack:
premium suppresses ads, so no ad budget ever comes due and every assertion about
one fails. Revoking the pack locally clears them.

**The daily ad break is still review-notes-only** and has been through three
reviews without comment.
