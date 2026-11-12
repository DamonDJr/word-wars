# Word Wars 0.54.2: App Store submission

The iPhone Duo release, corrected on a real Duo. Submit **0.54.2 build 4** as
**1.7.1**. It follows 1.7.0 (0.54.0 build 4, live), and nothing has been
submitted under 1.7.1 yet.

0.54.1 build 1 and 0.54.2 builds 1 to 3 went to TestFlight only and are
superseded: every fix in them is in build 4. Everything since 1.7.0 is about the
iPhone Duo; on any other device the game is unchanged.

## In App Store Connect

In this order, on the iOS app (6802900966):

1. **Add a version**: iOS, **1.7.1**.
2. **Build**: choose **0.54.2 (4)**, uploaded 5 November 2026. It is processed
   and valid, and export compliance is already answered (exempt).
3. **Screenshots**: under iPhone Duo, one folder per slot (below).
4. **What's New in This Version**: the block below.
5. **Promotional Text**: optional, the line below. It can be changed later
   without a new version.
6. **App Review Information, Notes**: the block below.
7. **Version Release**: automatically after approval, as 1.7.0 was. Pick manual
   instead if you want to choose the moment.
8. **Add for Review**, then **Submit**.

## Screenshots

Rendered by `tools/shots.sh --duo` into `build/shots/appstore-duo/`, one folder
per App Store Connect slot. Upload each folder's files in their numbered order:
the number is the order in the listing. Every file is the size its slot wants,
with no alpha channel, which is checked as they are written.

| iPhone Duo slot | Folder | Files |
|---|---|---|
| Inner display, landscape, 2853 x 2007 | `inner-landscape-2853x2007` | 6 |
| Inner display, portrait, 2007 x 2853 | `inner-portrait-2007x2853` | 6 |
| Outer display, portrait, 1398 x 2034 | `outer-portrait-1398x2034` | 6 |
| Outer display, landscape, 2034 x 1398 | `outer-landscape-2034x1398` | 4 |

The inner sets show the two folded layouts: the board standing over a full
keyboard held like a laptop, and a page each held like a book. Duo screenshots
are optional until April 2027 for apps built with the 27.1 SDK, and are provided
now anyway. `build/` is not in git, so rerun the command if the folder is gone.

## What's New in This Version

> Paste into App Store Connect, What's New. Limit is 4000 characters.

```
Made for iPhone Duo, now edge to edge: the game fills the whole of the
inner display.

Stand the Duo up like a laptop and the lower half becomes a full-size
keyboard, with the board on the half facing you. Fold it like a book and
you and your rival get a page each. The menus, the leaderboards and the
end-of-match summary flow round the fold as well.

Open it and the game fills the inner display the way you are holding it.
On the outer display, one big board and a keyboard across the whole
screen, and two boards when you turn it sideways. Survival on the open Duo
held sideways uses the full height.
```

## Promotional Text

> Optional. Paste into App Store Connect, Promotional Text. Limit is 170 characters.

```
Made for iPhone Duo: stand it up like a laptop for a full-size keyboard, or fold it like a book and you and your rival get a page each.
```

## App Review Notes

> Paste into App Store Connect, App Review Information, Notes.

```
WHAT CHANGED

Everything in this update is for iPhone Duo. On any other device the
game is unchanged.

Built with the iOS 27.1 SDK, so on iPhone Duo the game draws to the
edge of the screen instead of inside the frame given to older apps.

The game follows the hinge (UIHingeInteraction) and the fold's reserved
region. When the inner display is partly folded and held tall (like a
laptop), the board is on the upper half and the full keyboard fills the
lower half. Held wide (like a book), the keys split, one half on each
side of the fold; in a match your board is on the left page and your
rival's on the right, and with one board it stays in the middle. Partly
folded, every menu (the title screen, the end-of-match summary, the
leaderboards, settings) continues on the far side of the fold rather
than across it.

The game turns freely on iPhone Duo, on both displays, so opening the
device fills the inner display whichever way it is held. On the outer
display held upright it is one board with the keyboard across the full
width; turned sideways it shows both boards. Survival held sideways on
the inner display moves the clock to the side so the board can use the
full height.

HOW TO SEE THE CHANGES

On an iPhone Duo, or in the iPhone Duo simulator in Xcode's Device Hub:
open the game and play any match, then half-close the inner display and
stand it up. Open the title screen or the leaderboards while it is
half-closed to see the menus around the fold. SETTINGS shows, on its
last two lines, what the display measured as and what the hinge
reported.
```

## How it was built

```bash
RUNNER=xcode-27 XCODE=27.1 tools/ship-ios-crossplay.sh
```

Build 4 is commit `37081b0` on `crossplay`, built by CI run 42056912897 on
GitHub's `xcode-27` image with Xcode 27.1 `27A9275`, the released 27.1, which the
image carries as `Xcode_27.1_Release_Candidate.app`. The IPA reads
`DTXcodeBuild 27A9275` and `DTSDKName iphoneos27.1`, and the hinge bridge built
without a warning and is in the binary.

## What each build changed

| Build | What it carried |
|---|---|
| 0.54.1 (1) | Built with the released Xcode 27.1, edge to edge; the laptop keyboard |
| 0.54.2 (1) | The fold read from iOS itself; one board and a full-width keyboard on the outer display; survival held wide uses the height |
| 0.54.2 (2) | An attempt at turning the inner display on opening, replaced in build 3 |
| 0.54.2 (3) | Never locked on a Duo, so opening fills the inner display; a page each held as a book |
| 0.54.2 (4) | Every menu flows round the fold; the four sets of Duo screenshots |

## Before submitting

Check on the Duo, from TestFlight build 4:

- Closed and upright: one board, the keyboard across the whole width. Closed and
  turned on its side: the cover display turns, two boards, keys in the corners.
- Opened from the cover held upright: the inner display fills, wide, and is never
  a shrunken portrait. Opened from the cover held on its side: it fills, tall.
- Open flat, held either way, then half-closed: the layout moves off the crease
  within a moment, and back when opened flat again. Quickly as well as slowly.
- Half-closed like a book in a match: your board on the left page, the rival's on
  the right. In survival: one board in the middle, with the crease down it.
- Survival held wide: the clock in the right-hand corner, the board nearly the
  height of the glass.
- Half-closed, every menu (the title, the summary, the leaderboards, settings):
  nothing on the crease. Held as a laptop the screen carries on below it; held
  as a book it runs across the two pages, and the second page scrolls.
- Settings, last two lines: the second should start with `hinge` and end in
  `crease on` while half-closed. If it says `no regions` or has no `hinge`, the
  fold is not being read; send a screenshot of those two lines.
