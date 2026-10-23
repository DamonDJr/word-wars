# Word Wars 0.54.1: App Store review copy

The iPhone Duo release again, built with the released iOS 27.1 SDK. 0.54.0
(App Store 1.7.0) was built on Xcode 26.6 because the only 27.1 on a runner was
a beta, so on the Duo it runs in the inset frame the system gives an older app.
This build goes to the edge of the glass. One layout change rides along: held
like a laptop, the lower half of the inner display is all keyboard.

The App Store marketing version is yours to pick; **1.7.1** follows 1.7.0.

## How it was built

```bash
RUNNER=xcode-27 XCODE=27.1 tools/ship-ios-crossplay.sh
```

Xcode 27.1 was released on 15 October as `27A9275`, the same build as its RC.
GitHub's `xcode-27` image carries exactly that build, under
`Xcode_27.1_Release_Candidate.app` because the image was cut before Apple's
release. The script prints `DTXcodeBuild` and `DTSDKName` from the IPA before it
uploads; they should read `27A9275` and `iphoneos27.1`.

## What's New in This Version

> Paste into App Store Connect, What's New. Limit is 4000 characters.

```
Made for iPhone Duo, now edge to edge: the game fills the whole of the
inner display.

Stand the Duo up like a laptop and the lower half becomes a full-size
keyboard, with the board on the half facing you.
```

## App Review Notes

> Paste into App Store Connect, App Review Information, Notes.

```
WHAT CHANGED

Built with the iOS 27.1 SDK, so on iPhone Duo the game draws to the
edge of the screen instead of inside the frame given to older apps.

When the inner display is partly folded and held tall (like a
laptop), the keyboard now fills the lower half: the full keyboard,
whatever the "Split keyboard" setting says. Held wide (like a book),
it is split as before, one half on each side of the fold.

HOW TO SEE THE CHANGES

On an iPhone Duo, or in the iPhone Duo simulator in Xcode's Device Hub:
open the game and play any match. Half-close the inner display and stand
it up. SETTINGS shows, on its last line, what the display measured as.

On any other device nothing is different.
```
