# Word Wars on iOS

Two separate problems, and only one of them is about Xcode.

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

### The way round it

Build on a hosted macOS runner. `.github/workflows/ios.yml` does the whole
thing: installs Godot and the templates, exports the Xcode project, builds it
**unsigned** with `CODE_SIGNING_ALLOWED=NO`, and zips a `Payload/` folder into an
IPA — the same trick `tools/build-ipa.sh` uses in the other two projects.

The Mac is then only ever asked to run Sideloadly, which Big Sur does fine.

Run it from the Actions tab, download the artifact, sideload it. Expect the
first run to need a fix or two: it has never been run, because there is no Mac
here to run it on.

One trap it is already carrying: `include_filter="data/*.txt"` in the iOS
preset. The word lists are plain text rather than imported resources, so without
that line the game ships with an empty dictionary and rejects every word — and
unlike the desktop build there is no headless boot to grep afterwards, so
nothing downstream would catch it.

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
