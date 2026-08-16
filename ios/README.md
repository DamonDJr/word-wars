# Word Wars on iOS

**Status: there is a working IPA.** CI builds it, it is arm64, it carries the
dictionary, and it is unsigned on purpose. What is left is plugging the phone
in. See "How to install it" below.

Two separate problems, and only one of them is about Xcode.

## 0. The preset had never exported once

Worth recording, because the first bug hid the second and the second was the
one that mattered.

`export_presets.cfg` had its comments written with `#`. Godot's `ConfigFile`
comments with `;` — a `#` does not get ignored, it **stops the parse**, and
every section after it silently vanishes. The iOS preset was below such a
comment, so Godot never saw it. I had read that as "Linux does not register the
iOS platform", which was wrong and was never tested.

With the comments fixed the real error surfaced immediately:

```
ERROR: Cannot export project with preset "iOS" due to configuration errors:
App Store Team ID not specified.
```

Godot refuses to export iOS with an empty team ID. It is now the
free-provisioning team this Apple ID already carries — a field Godot will not
leave blank, not a signing decision, since the build ships unsigned and is
re-signed at install.

The other change is `application/export_project_only=true`. Godot otherwise
tries to run `xcodebuild` at the end of the export, which cannot work here. With
it set, the export is plain file writing, so **it runs on Linux** — and that is
what lets `tools/build.sh` catch the one silent failure this platform has, the
missing dictionary, without waiting on a runner.

## 1. Big Sur cannot build this, and it is not close

Godot never builds an iOS binary itself. It exports an **Xcode project**, and you
build that. So the toolchain question is the whole question, and it has a
measurable answer — from the 4.7 export templates already on this machine:

```
libgodot.ios.release.xcframework/ios-arm64/libgodot.a
    minimum iOS 14.0, built against SDK 26.1
```

The newest Xcode that runs on Big Sur is **13.2.1**, carrying the **iOS 15.2**
SDK. Linking objects built against the iOS 26.1 SDK with that is not a setting
to find; the toolchain is five generations short.

Worth being clear about what is *not* the problem:

- **Not the deployment target.** The templates want iOS 14.0 and every phone
  worth sideloading to is past that.
- **Not Vulkan.** This project renders with `gl_compatibility`, so the MoltenVK
  slice in the template is never linked. Had it been Vulkan, the floor would be
  iOS 16.
- **Not signing.** That was already solved for Kinetica and LegendFood.

### The way round it: build in CI, install locally

Split the two jobs apart. Nothing then needs the Mac at all.

**Build** on a hosted macOS runner. `.github/workflows/ios.yml` installs Godot
and the templates, exports the Xcode project, builds it **unsigned**, and zips a
`Payload/` folder into an IPA — the same trick `tools/build-ipa.sh` uses in the
other two projects. It passed on its first run and produced this:

```
Payload/WordWars.app/WordWars   Mach-O 64-bit arm64 executable
CFBundleIdentifier              com.damonj.wordwars
MinimumOSVersion                14.0
UISupportedInterfaceOrientations  [Portrait]
DTSDKName                       iphoneos26.5
_CodeSignature                  absent, as intended
WordWars.pck                    carries data/words.txt and data/common.txt
```

48 MB. Grab it from the run's artifacts, or `gh run download <id> -n
WordWars-ios-unsigned`.

One detail worth knowing before re-signing: the app has a
`Frameworks/libswift_Concurrency.dylib` in it. Nested code has to be signed too,
and both installers below do that — but a hand-rolled `codesign` on the bundle
alone would produce something that installs and then refuses to launch.

Turning signing off needed more than the obvious flag. Godot writes the project
with `CODE_SIGN_STYLE = Automatic` and a team, and automatic signing resolves a
provisioning profile *before* it reads `CODE_SIGNING_ALLOWED` — so on a runner
with no Apple account it fails first. Forcing `CODE_SIGN_STYLE=Manual` with an
empty `DEVELOPMENT_TEAM` is what actually turns it off.

### How to install it

Two routes, and the Mac is only one of them.

**From Linux, with [xtool](https://github.com/xtool-org/xtool).** Already set up
on this machine — Kinetica uses it, `xtool auth status` is logged in and the
token runs to 2027. So the setup friction is behind us, not ahead:

```bash
sudo systemctl start usbmuxd
xtool devices
xtool install WordWars.ipa
```

`usbmuxd` is currently inactive and no phone is attached, which is the whole of
what is left. Note that xtool cannot *build* this — it builds SwiftPM packages,
and Godot emits an Xcode project full of prebuilt static libraries and
Objective-C++. That is the half CI is doing. `xtool install` is a separate
command that takes a finished `.ipa` and does not care what produced it.

**From the Big Sur Mac, with Sideloadly.** Exactly the Kinetica and LegendFood
process, on an IPA that was downloaded rather than built. The Mac never compiles
anything, so its Xcode version stops mattering.

From xtool's source rather than its docs, which do not spell this out:

- `IntegratedInstaller.install(app:)` accepts a `.ipa`, unpacks it, finds the
  `.app` inside `Payload/`, calls **`signInPlace`**, repacks and installs. It
  signs what you give it — it does not need an already-signed build.
- `DeveloperServicesProvisioningOperation` runs
  `DeveloperServicesAddDeviceOperation`, so it **registers the device with
  Apple** itself. That is precisely the circle Xcode 13.2.1 could not square.
- `DeveloperServicesTeam` carries an `isFree` flag, so a free Apple ID is a
  handled case rather than an accident that happens to work.

It is also engine-agnostic: it operates on the built `.app`, so nothing about it
cares that Godot produced it.

The free-ID limits are the ones already lived with — seven-day certificates,
three apps, re-install weekly. Word Wars would be the third alongside Kinetica
and LegendFood, so something has to give if a fourth ever shows up.

The trap the preset carries is `include_filter="data/*.txt"`. The word lists are
plain text rather than imported resources, so without that line the game ships
with an empty dictionary and rejects every word. There is no headless iOS boot
to grep afterwards, so it is checked three times instead: on the pck in
`tools/build.sh`, on the pck in CI, and on the built `.app` before it is zipped.

## 2. It is a typing game

This is the real work, and no amount of build configuration touches it.

**The keyboard eats the game.** The software keyboard covers roughly 40% of a
phone screen. The current layout is 1280x720 landscape with up to four boards
side by side. In portrait with a keyboard up there is something like 390x420pt
left, which is one board and nothing else.

**Every tuned number assumes a physical keyboard.** A good phone typist manages
35-40 wpm against 70-100 on keys. `CHAIN_BASE` and `CHAIN_PER_CHAR`, the
pressure clock, the CPU roster from 26 to 58 wpm, the reach formula — all of it
was balanced against hands on a keyboard. Ported unchanged, Rookie becomes
Wordsmith.

**The mastery system inherits the same problem.** `Speed Demon` wants 65 wpm.
On glass that is not a stretch goal, it is a wall.

### What is built so far

The layout half is done and testable today — drag a desktop window narrow and
the game changes shape, because the orientation is decided by measuring the
window rather than by asking what platform this is. That is the only reason any
of it could be built without an iPhone in the room.

- **A portrait design space of 720x1440**, swapped in at runtime via
  `content_scale_size`, with `stretch/aspect = expand` so the long axis takes
  whatever the screen actually has. 1:2 is a design *floor*, not a shape every
  phone agrees to be — a Pro Max is 1:2.17, and under the old `keep` it played
  with a black band at each end.
- **Safe-area insets**, measured once per orientation change and applied to the
  header, the board and the keyboard. Filling the screen is what makes these
  necessary: the clock was behind the Dynamic Island and the FIRE key was under
  the home indicator. `godot -- --safe=104,42` forces them, so a notch can be
  laid out from a desktop window.
- **A portrait match layout**: one board sized from the room left over after the
  keyboard takes its share, rivals reduced to chips along the top. You cannot
  read four boards on a phone, and pretending otherwise costs the one board you
  can read.
- **A drawn keyboard** — three rows, QWERTY, plus DEL and FIRE. Alphabetical
  looks tidier and is slower for everyone who has ever used a phone.
- **A back button**, top-left, in portrait only. A phone has no Escape, and
  every screen in this game was leaving by it. It does whatever Escape does on
  the screen you are on, read off the same phase table so the two cannot drift.
  There is no quit: iOS apps are not meant to have one, so on the title screen
  the button simply is not drawn.

The keyboard used to know the board — keys dimmed when no word began that way,
lit when they opened a stamp you were facing. Good on paper and wrong in the
hand: twenty-six keys changing colour on every keystroke is motion in the part
of the screen you are not looking at, and it read as flicker under the thumbs.
The information was real and the distraction was worse. Removed.

- **Every menu reflows.** One helper, `_grid_rects`, lays out every card grid in
  the game — the mastery record strip and its unlock grid, the opponent roster,
  the block switches, the room seats, the summary tiles. It shrinks cards until
  they would go under a stated minimum and only then drops a column, which is
  what keeps four seats reading as one table instead of wrapping to 3 + 1. The
  desktop numbers are what it aims for and at 1280 nothing binds, so landscape
  is unchanged.
- **The rules panel wraps.** It was 860px of hand-broken lines against a 720px
  screen. The paragraphs are sentences now and the font breaks them, and the
  panel is measured to its contents rather than to a constant.
- **The system keyboard for text fields.** The drawn keyboard is letters, DEL
  and FIRE — no digits, no paste. A room code has both. So the lobby and the
  name field raise the iOS keyboard instead, and Godot delivers what is typed
  on it as ordinary key events, which means there is no second implementation
  of what a keystroke means.
- **Nothing claims a key the phone does not have.** Key badges (ESC, ENTER,
  CTRL+H) are suppressed in portrait, the fullscreen switch is gone, and the
  rules say "the FIRE key" where they said SPACE or ENTER.
- **Attack rails down both gutters.** A phone board is one column of playfield
  with a hand's width of nothing either side, and what used to be in that space
  was the words "3 incoming". Now the desktop chips live there: left is what is
  falling on you, with prefixes, tier pips and fuses, and the white border that
  says the word you are typing will catch it. Right is your target's queue —
  your own attacks still in the air, which `_on_net_state` already mirrors at
  15 Hz, so the rail is live against a person and not only against a CPU.
- **Haptics**, in `scripts/haptics.gd`, as a named vocabulary rather than
  durations sprinkled through the match code. Two rules run it: nothing may
  drown out anything (a weaker event landing inside 60ms of a stronger one is
  dropped rather than queued, because the hand cannot separate them), and typing
  is the floor. There is a switch in settings, portrait only.

  The shape of the table comes from what the template can actually emit, which
  is worth knowing before tuning it. Godot drives `vibrate_handheld` through
  Core Haptics, but only ever as `CHHapticEventTypeHapticContinuous` — there is
  no transient event in there — and it sets intensity with no sharpness. So
  **these are rumbles, not clicks**: anything under about 25ms is gone before
  the actuator has spun up, and nothing can be made crisp. The first version was
  tuned as though they were taps, with a 9ms keystroke, and was reported back as
  too faint to feel. Everything is two to three times longer now and most of it
  sits on the intensity ceiling, which is also why `scale` spends its overflow
  on duration — a three-block break has nowhere else left to be bigger.

- **The splash art, in all three places it appears.** iOS shows a launch
  storyboard from the moment the icon is tapped, then the engine paints its own
  boot splash, then the game draws one over the menu assembling underneath. Miss
  one and the opening is three different pictures in half a second. The
  storyboard comes from `storyboard/custom_image@2x/@3x` in the preset at
  "Scale to Fit", the boot splash from a `boot_splash/image.ios` feature
  override, and the drawn one picks its cut by orientation. Feature overrides
  are resolved in exported builds and ignored in the editor, so reading that
  setting back from a project folder always shows the landscape one — measure it
  from an export or not at all.

### Still to do

- **The balance pass.** Nothing below has been touched yet.

### What a mobile version would actually be

- **Portrait, one board.** Free-for-all does not survive a phone screen; a duel
  does.
- **A drawn keyboard rather than the system one.** Everything in this game is
  already custom `_draw`, so a compact three-row keyboard is the same kind of
  code as the rest of it — and it buys things the system keyboard cannot: no
  autocorrect fighting the dictionary, no layout jumping about, and the ability
  to **light up the letters that open a stamp currently on your board**. That is
  a better mobile design than a raw keyboard rather than a compromise.
- **A second balance pass**, in its own table rather than by editing the
  existing constants, so desktop tuning is not collateral damage.

None of that is speculative work that might be thrown away — it is the port.
The build pipeline above is perhaps a day; this is the rest of it.
