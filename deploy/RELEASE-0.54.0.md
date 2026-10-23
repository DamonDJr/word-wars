# Word Wars 0.54.0: App Store review copy

The iPhone Duo release. The game fills both of the Duo's displays, can be held
wide on the inner one with the keys out at the sides and the board down the
middle, and, when the device is partly folded, keeps the board, the keys and the
word you are typing off the crease. Nothing changes on any other iPhone, and
nothing is new to sell. Three blocks below: the first goes in **App Review
Information → Notes**, the second in **What's New in This Version**, and the
third is the screenshot upload map.

`0.54.0` is this repository's build track. The App Store marketing version is
**yours to pick**; **1.7.0** is the suggestion, since this adds a device class
and a screenshot set rather than fixing something.

The device ships on **Friday 23 October 2026**. See "Getting it live on the day"
at the bottom for what has to be true by when.

## What has been checked, and what has not

This was built with no Duo in the room and no simulator on the machine it was
built on, from Apple's published guidance and panel numbers. Read the two halves
of this table as different kinds of claim.

| Checked here | How |
|---|---|
| The size class comes out right for every device in the table, including the one pair the old test could not tell apart (a Duo's cover display and an iPad) | `tools/duotest.gd -- classify`, 13 cases |
| In every pose, no key, no board and no control is under the island's column or the crease, and every letter key is at least as big in inches as an iPhone 15's | `tools/duotest.sh`, 8 poses |
| Tapping the middle of every key types that key, in all three keyboard forms | the same |
| Opening, closing, turning and partly folding the device mid-match keeps the blocks, the half-typed word, the phase and the score | the same, 6 transitions, each checked on the way back too |
| A hinge reading becomes a crease only on the angle, whatever the status number is | `tools/duotest.gd -- hinge`, 12 cases |
| Nothing else regressed | every other test in `tools/`: the same failures as before this change and no others (`survivaltest` 18, `cloudtest` 3, both pre-existing and unrelated) |
| What every pose looks like | `tools/shots.sh --duo`, the screenshots below |

| **Not** checked | Why it matters |
|---|---|
| `screen_get_scale()` on a two-display device | the size class depends on it; if it came back 1.0 an iPhone would measure as regular and rotate |
| The island's real insets | they are invented in the pose table; the game reads the real ones at run time |
| Whether the hinge interaction attaches and reports radians | the crease layout only happens if it does; if it does not, the layout is the unfolded one |
| The real width of the crease | estimated at 5.5% of the long side |

**The first thing to do with a build on a Duo or in Device Hub** is open
Settings and read the last line. It says what the game thought it was looking at:

```
1398x2034 px · 3.00x · 466pt · compact · tablet · safe 0 44 0 100
2007x2853 px · 3.00x · 669pt · regular · tablet · safe 30 44 0 0
```

Those are the numbers the first four rows above are about. If they are what is
printed here, most of the risk is gone. A "Work around the fold" row beneath the
split keyboard switch means the hinge bridge attached and has written something.

## Which build to submit

**The first 0.54.0 build that has been opened on a Duo or in the simulator and
whose Settings line reads as above.** Until one has, the TestFlight build is the
test, not the release. Nothing in this one is a reason to wait on any other
change.

## What this release covers

| Change | Who gets it | Kind |
|---|---|---|
| Fills the iPhone Duo's outer and inner displays, to the edge when built with the 27.1 SDK | iPhone Duo | new |
| Turns freely on the inner display and on iPad, with the keys at the two sides and the board in the middle | iPhone Duo (inner), iPad | new |
| Keeps the board, the keys and the word off the crease when the Duo is partly folded | iPhone Duo | new |
| A split keyboard is only offered where there is room for one; the cover display no longer is | iPhone Duo | fix |
| The Fullscreen switch is back in Settings on desktop, where a landscape window was being mistaken for a tablet | desktop | fix |

**iPad now turns.** The game was locked to portrait on every device, so an iPad
stayed upright whichever way it was held. It turns now, and held wide it gets the
Duo's layout: the keys at the two sides and the board between them. That is a
visible change for iPad players, and the one place this release touches a device
that is not a Duo.

**Compact screens stay in portrait.** An iPhone, and the Duo's cover display, are
held to portrait. A board 0.19 inches a cell upright is 0.12 held sideways with
keys at the sides; the cover display comes out the same either way. Apple's own
guidance for a game is that locking is fine so long as the screen is filled.

## App Privacy: no change

Nothing new is collected or sent. The game now writes one line of text — how far
the hinge is open — to the app's own caches directory, and reads it back. It is
not logged and not transmitted, and the policy's existing statement that nothing
leaves the device beyond Game Center, Epic matchmaking and the ad SDK still
holds.

**Export compliance:** unchanged.

---

## App Review Notes

> Paste into App Store Connect → App Review Information → Notes. Limit is
> 4,000 characters.

```
No new permissions, no new in-app purchase products, and no change to
the price, the advertising SDK, the data collected, the network use,
the share rewards, or the user-generated content answers given at the
last review.

WHAT CHANGED

Layout for iPhone Duo. On the outer display the game keeps its
controls clear of the status bar and Dynamic Island column. On the
inner display it can be held either way up; held wide, the keyboard is
split into two halves at the lower corners with the playfield between
them, with a FIRE key under each half. When the device is partly folded, the
playfield and the word being typed move off the crease. There is a switch for that,
"Work around the fold", in SETTINGS on a device that can fold.

iPhones are unchanged. An iPad now turns to landscape, where it gets the
same two-sided keyboard layout as the Duo's inner display.

HOW TO SEE THE CHANGES

On an iPhone Duo, or in the iPhone Duo simulator in Xcode's Device Hub:
open the game and play any match. Fold and unfold the device, turn it,
and half-close it. The match carries on through all of it. SETTINGS shows,
on its last line, what the display measured as.

On any other device nothing is visible beyond the above.

VERSUS, ACCOUNTS, ADVERTS AND CLOUD SAVE

Unchanged. Versus still runs on Epic Online Services with anonymous
Device ID sign-in. There is no field anywhere in the app where a player
types text another player can see. RESTORE PURCHASES is in SETTINGS.
```

*(About 1,500 characters.)*

---

## What's New in This Version

> Paste into App Store Connect → What's New in This Version. Limit is 4,000
> characters.

```
BUILT FOR IPHONE DUO

Word Wars now fills both of the Duo's displays. Open it and the match
gets the whole inner screen: a bigger board down the middle, with the
keys out at the two sides under your thumbs. Fold the phone partway and
the board and keys move off the crease.

A match you start on the cover display carries on when you open it.

IPAD

Word Wars now turns to landscape on iPad, with the keys at the two sides.
```

---

## Screenshot upload map

`tools/shots.sh --duo` writes one folder per pose under `build/shots/duo/`. In
App Store Connect they go under **iPhone Duo**, which lists the two displays
separately:

| Folder | Size | App Store Connect slot |
|---|---|---|
| `outer-portrait/` | 1398 × 2034 | iPhone Duo, outer display, portrait |
| `inner-portrait/` | 2007 × 2853 | iPhone Duo, inner display, portrait |
| `inner-landscape/` | 2853 × 2007 | iPhone Duo, inner display, landscape |

There is no `2034 × 1398` set because the game does not turn on the outer
display. Each folder holds the same seven shots in the same order, with no
caption furniture and no alpha channel. Up to ten are allowed per size.

`build/shots/duo/inner-portrait-laptop/` and `inner-landscape-book/` are the
partly folded layouts, for the press kit and not for the listing: a listing
should show what every player sees first.

**Screenshots are optional for now.** Apple's page says they become required in
April 2027 for apps built with the iOS 27.1 SDK or later.

---

## The listing

**Description: no change needed.** If a line is wanted, the honest one is under
MODES or at the foot:

> Built for iPhone Duo: the board gets the whole inner display, and the game
> moves off the crease when you fold it.

**Promotional Text: your call.** The current one is about the redraw and the
lesson, which is still true. It is the one field that can change without a new
review, so it is the right place to put "Built for iPhone Duo" on the day.

---

## Getting it live on the day

Apple does not give a review time, but a normal one is a day or two and a
rejection costs a resubmission. Counting back from Friday 23 October:

| By | What |
|---|---|
| Mon 12 Oct | Merge this branch, trigger `ios.yml`, read the SDK line in the log. TestFlight build 1 |
| Tue 13 – Wed 14 | A Duo or Device Hub run: read the Settings line, fold and turn it. Fix what that finds |
| Thu 15 | The build to submit. Upload the screenshots |
| Fri 16 | Submit for review with **Manually release this version** selected |
| Mon 19 – Tue 20 | Slack for one rejection and one resubmission |
| Fri 23 | Release |

Two things that could move this, both outside the repository:

- **Which runner.** `macos-latest` has Xcode 26.6 only. The iOS 27.1 SDK is on
  GitHub's preview image, `xcode-27`, which also carries a 27.2 *beta* that App
  Store Connect would refuse; the workflow takes the runner and the Xcode as
  inputs and never picks a beta on its own:

  ```bash
  gh workflow run ios.yml --ref crossplay -f runner=xcode-27 -f xcode=27.1
  ```

  Builds 2 and 3 were made this way (Xcode 27.1, build 27A9269, `iphoneos27.1`).
  **TestFlight takes them; App Review does not.** That 27.1 was Apple's *beta*
  (Xcode build `27A9269`, SDK build `24A94403`) and submission refuses it as a
  beta toolchain. Build 4 is the plain `gh workflow run ios.yml --ref crossplay`
  on `macos-latest` (Xcode 26.6, `17F113`, SDK 26.5).

  What that costs: the Duo to-the-edge layout needs the 27.1 SDK, so build 4
  runs in the inset frame the system gives it, which the game lays out against.

  **Xcode 27.1 was released on 15 October as `27A9275`**, the same build as its
  RC, and the `xcode-27` image carries exactly that build (checked 21 October,
  image `20261012.0260.1`). It sits under `Xcode_27.1_Release_Candidate.app`
  because the image was cut three days before Apple's release, and
  `-f xcode=27.1` reaches it through the `Xcode_27.1.app` symlink.

  Build 4 went live as 1.7.0, which closes the 0.54.0 train to new uploads, so
  the rebuild is **0.54.1** (`deploy/RELEASE-0.54.1.md`).
- **Whether the hinge bridge builds.** It is a warning and not a failure if it
  does not: the build goes on without it and lays out unfolded.
