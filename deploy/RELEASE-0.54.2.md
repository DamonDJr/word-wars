# Word Wars 0.54.2: App Store review copy

The iPhone Duo release, corrected on a real Duo. 0.54.1 build 1 went to
TestFlight and was never submitted; on the device it did not notice the hinge,
put two boards too small to read on the cover display, held its keyboard off a
sidebar that was not there, and left survival held wide a small board between
two wings. This build fixes all four, and goes in as 1.7.1 in 0.54.1's place.

The App Store marketing version is yours to pick; **1.7.1** follows 1.7.0, and
nothing has been submitted under it yet.

## How it was built

```bash
RUNNER=xcode-27 XCODE=27.1 tools/ship-ios-crossplay.sh
```

The same runner and Xcode as 0.54.1: `27A9275`, the released 27.1, which GitHub's
`xcode-27` image carries as `Xcode_27.1_Release_Candidate.app`. The script prints
`DTXcodeBuild` and `DTSDKName` from the IPA before it uploads; they should read
`27A9275` and `iphoneos27.1`. The build log's "Hinge bridge" step should say
`present`: the bridge now uses the 27.1 headers for the hinge status names, and
a build without it still plays, but does not see the fold.

## Before submitting

Check on the Duo, from TestFlight:

- Closed: one board, the keyboard across the whole width.
- Open flat, held either way, then half-closed: the layout moves off the crease
  within a moment, and back when opened flat again. Quickly as well as slowly.
- Opened from the cover held upright: the inner display turns wide by itself,
  within a second. Opened from the cover held on its side: it stays tall.
- Closed again from held wide: the cover display comes up in portrait.
- Survival held wide: the clock in the right-hand corner, the board nearly the
  height of the glass.
- Settings, last two lines: the second should start with `hinge` and end in
  `crease on` while half-closed. If it says `no regions` or has no `hinge`, the
  fold is not being read; send a screenshot of those two lines.

## What's New in This Version

> Paste into App Store Connect, What's New. Limit is 4000 characters.

```
Made for iPhone Duo, now edge to edge: the game fills the whole of the
inner display.

Stand the Duo up like a laptop and the lower half becomes a full-size
keyboard, with the board on the half facing you. Fold it like a book and
the board moves clear of the crease.

On the outer display, one big board and a keyboard across the whole
screen. Survival on the open Duo held sideways uses the full height.
```

## App Review Notes

> Paste into App Store Connect, App Review Information, Notes.

```
WHAT CHANGED

Built with the iOS 27.1 SDK, so on iPhone Duo the game draws to the
edge of the screen instead of inside the frame given to older apps.

The game follows the hinge (UIHingeInteraction) and the fold's reserved
region. When the inner display is partly folded and held tall (like a
laptop), the board is on the upper half and the full keyboard fills the
lower half. Held wide (like a book), the keys split, one half on each
side of the fold, and the board stays on one side of it.

On the outer display the game is one board with the keyboard across the
full width. Survival held sideways on the inner display moves the clock
to the side so the board can use the full height.

HOW TO SEE THE CHANGES

On an iPhone Duo, or in the iPhone Duo simulator in Xcode's Device Hub:
open the game and play any match, then half-close the inner display and
stand it up. SETTINGS shows, on its last two lines, what the display
measured as and what the hinge reported.

On any other device nothing is different.
```
