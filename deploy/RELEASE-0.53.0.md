# Word Wars 0.53.0 (build 6): App Store review copy

The 3D boards, a new board you earn in versus, unlocks you can watch, the
Premium block styles redrawn, and a new icon. Three blocks below: the first
goes in **App Review Information → Notes**, the second in **What's New in This
Version**, the third in **Promotional Text**. This version also replaces the
**screenshots** and **App Previews**; new ones are rendered and ready (see
*The listing*).

`0.53.0` is this repository's build track. The App Store marketing version is
**yours to pick, and no version exists for it in App Store Connect yet**.
**1.6.0** is the suggestion: every Premium board is a different thing now, and
there's a new board and a new icon. (0.52.0's notes suggested 1.6.0 too; it
went out as 1.5.6.)

Checked against App Store Connect on 2026-09-30:

```bash
asc versions list --app 6802900966
asc builds list --app 6802900966 --limit 8
asc versions view --version-id <1.5.6> --include-build
```

| | Binary | Listing | State |
|---|---|---|---|
| Previous | `0.52.0` build 2 | **1.5.6** | `READY_FOR_SALE`, created 2026-09-27 |
| This one | `0.53.0` build 6 | **1.6.0**, suggested | `VALID`, uploaded 2026-09-30 from `crossplay` at `a1001fe` |

## Which build to submit

**Build 6.** It's the only 0.53.0 build with everything below in it. Every
earlier one is a TestFlight step on the way.

| Build | What it adds | Submit? |
|---|---|---|
| 1 | Clouds, Volcano and Cyber as live 3D scenes | no |
| 2 | the other six boards in 3D; Cumulus, Magma and Neon block faces redrawn | no |
| 3 | Subway, free; Cyber's camera on the pavement | no |
| 4 | unlocks as full-screen events; Subway earned in versus | no |
| 5 | seven Premium block styles redrawn to match their boards | no |
| 6 | the new App Store icon | **yes** |

## What this release covers

| Change | Who gets it | Kind |
|---|---|---|
| The eight Premium boards and Nexus are live 3D scenes, not still pictures | premium, sharers | feature |
| Subway, a new 3D board: free, unlocked by 3 versus matches against real people | everyone | feature |
| Earning a board unveils it full-screen on its own running scene, with "Use it now" | everyone | feature |
| Buying the Premium pack deals its boards out one by one | buyers | feature |
| Owners of the pack get a one-time "Founder" thank-you on first launch | premium | feature |
| Versus lobby and versus results show the Subway count | everyone | polish |
| Premium block styles redrawn in the boards' own toon style, with ink | premium, sharers | design |
| New App Store icon: BloqBot, star-eyed, with the wordmark's W tiles | everyone | design |

**The boards.** Built in Blender (`tools/blender/`), exported as glTF to
`boards/3d/`, and drawn behind the game by `scripts/board3d.gd` in toon
shaders. Each plays its own animation on a loop. The 3D render is capped at 1.25x the
layout resolution, so a phone isn't rendering a full-resolution scene to sit
dimmed behind the board. The nine scenes add about 23 MB to the bundle, and
their stills (shop and wardrobe previews) about 2 MB. `godot -- --board2d`
puts the old pictures back, for comparing.

**Subway.** Three finished versus matches against a person, won or lost.
A match the opponent walks out of counts; CPU matches don't. The count is a
new field in the profile record (`versus`), saved and cloud-merged like the
others. Nobody has any yet: nothing counted versus matches before this build.

**The unlock events.** A board earned by playing (Subway, Nexus, anything
added later with a non-money unlock) is unveiled when it's earned. The
pack's unveiling is owed to anyone who owns the pack and hasn't seen it,
which includes everyone who bought it before this existed. It is keyed to
`PROMO_DROP`, so **bump `PROMO_DROP` whenever the pack gains content** and
every owner is shown it again. It never appears over a running match or an
ad break, and only after a results screen has been up for 1.6 seconds.

**The block styles.** Magma, Coral, Glacier, Heartwood, Sandstone, Nebula and
Rune are redrawn; Cumulus and Neon are unchanged. Every tier keeps its
colour. Painting a full board of each costs about what Cumulus already did
(measured on desktop: Coral and Heartwood about 13% more, the rest equal or
less). `tools/faceshots.gd` renders them all close up in a few seconds.

**The icon.** `tools/appicon_art.py` builds it from BloqBot's hand-drawn hype
frame and the wordmark's tiles. 1024x1024, no alpha channel. With `--android`
it also writes the Android launcher set in `packaging/android/`: the adaptive
layers use a tighter layout, so his face and the tiles stay inside the circle
every launcher mask keeps, and the themed (one-colour) layer keeps his face
and both tiles.

---

## App Privacy: no change

Nothing new is collected. The versus count is a number in the player's own
record, stored on the device and in their Game Center cloud save, which the
live policy already covers under *What is stored on your device* and *Cloud
saves*. The 3D scenes are bundled, not downloaded. Versus, Epic,
adverts and the purchase are unchanged from 1.5.6.

**Export compliance:** unchanged.

---

## App Review Notes

> Paste into App Store Connect → App Review Information → Notes. Limit is
> 4,000 characters.

```
No new permissions, no new in-app purchase products, and no change to
the price, the advertising SDK, the data collected, the network use,
the share rewards, or the user-generated content answers given at the
last review (1.5.6).

WHAT CHANGED

This version is mostly visual. How the game plays and what it sells
are unchanged.

The boards: the eight board themes in the Premium pack, and the Nexus
board earned by sharing, are now 3D scenes rendered on the device
behind the game, in place of still pictures. Every scene is bundled
with the app; nothing is downloaded.

A new board, Subway, is free. It unlocks after a player has finished
three versus matches against other people, won or lost. It is not sold
and is not part of the Premium pack.

Unlocking a board now shows a short full-screen animation of the board,
with "Use it now" and "Later" buttons. Buying the Premium pack shows a
similar animation dealing out the pack's boards. Players who already
own the pack see a one-time thank-you version of it.

The Premium block styles were redrawn to match their boards, and the
app has a new icon featuring the game's mascot, BloqBot, a character
drawn for this game.

PREMIUM PACK

Unchanged in price and contents. The same eight boards and the same
block styles, now animated in 3D and redrawn.

HOW TO SEE THE CHANGES

The boards are in COSMETICS > BOARD THEME; each shows a still of its
scene, and a locked board says how to earn it (Subway reads "play 3
versus matches"). Buying the Premium pack in the sandbox shows the
pack animation and makes every Premium board wearable. Equipping one
puts its scene behind the playfield in every match. The Subway unlock
needs three matches against other players on two devices, so it can be
checked from the wardrobe and the versus lobby, which shows how many
matches are left.

VERSUS, ACCOUNTS, ADVERTS AND CLOUD SAVE

Unchanged from 1.5.6. Versus still runs on Epic Online Services with
anonymous Device ID sign-in. The count of versus matches played is kept
with the player's other records, on the device and in their own Game
Center cloud save. There is no field anywhere in the app where a player
types text another player can see. RESTORE PURCHASES is in SETTINGS.
```

*(About 2,200 characters.)*

---

## What's New in This Version

> Paste into App Store Connect → What's New in This Version. Limit is 4,000
> characters.

```
THE BOARDS ARE NOW LIVING 3D WORLDS

The Premium boards and Nexus have been rebuilt as 3D scenes that move
behind your game.

• Volcano erupts over a field of cracked lava.
• Ocean is a reef canyon with jellyfish, a school of fish and a passing
  whale.
• Cyber is a rainy night street, with traffic and people walking by.
• Clouds, Forest, Space, Desert, Aurora and Nexus each have a scene of
  their own.

A NEW BOARD: SUBWAY

A dim station with a train that pulls in, waits and leaves. It's free:
play 3 versus matches against real people and it's yours.

UNLOCKS WORTH WATCHING

• Earn a board and it's unveiled in full, with its scene running.
• Get the Premium pack and its boards are dealt out one by one.
• Already own the pack? Open the game. There's a thank-you waiting.

NEW BLOCK STYLES

The Premium block styles are redrawn to match their boards: basalt
cracked with lava, reef stone with coral, glacier ice under snow, mossy
timber and more.

AND A NEW ICON

BloqBot is on your home screen now.
```

---

## Promotional Text

> Paste into App Store Connect → Promotional Text. Limit is 170 characters.
> Changeable without shipping a build.

```
The Premium boards are now living 3D worlds, and there's a new Subway board you earn in versus. Plus block styles redrawn to match, and BloqBot on the icon.
```

*(156 characters.)*

---

## The listing

**Screenshots: replace them, from `build/shots/store/`.** Re-rendered on
2026-09-30 from this build, with `tools/store-shots.sh`: the boards behind play
are the 3D scenes and the blocks wear the redrawn styles. Eight cards now, not
seven: **04-unlock** is new, Subway's unveiling, captioned "EARN NEW BOARDS. /
PLAY VERSUS, UNLOCK SUBWAY." It carries no Premium tag, because Subway is free.
07-boards now reads "8 BOARDS, ALL IN 3D." The rest keep their captions and,
on Premium boards, their PREMIUM BOARD tags (guideline 2.3.2).

| Set | Folder | Size | Upload as |
|---|---|---|---|
| iPhone | `build/shots/store/iphone/01-launch.png` … `08-leaderboard.png` | 1320 x 2868, RGB | iPhone 6.9" |
| iPad | `build/shots/store/ipad/01-launch.png` … `08-leaderboard.png` | 2064 x 2752, RGB | iPad 13" |

Delete the live set and upload these in file order; the first three are what
most people see.

**App Previews: replace them too.** Re-recorded and re-cut on 2026-09-30, the
same five-scene arc on Volcano, Space, Clouds, Cyber and Forest, now as 3D
scenes with the new block styles. Every scene keeps its PREMIUM BOARD tag.

| File | Size | Length | Upload as |
|---|---|---|---|
| `build/trailer/word-wars-preview.mp4` | 886 x 1920, 30fps, H.264, stereo AAC | 27.6s | iPhone 6.9" |
| `build/trailer/word-wars-preview-ipad.mp4` | 1200 x 1600, 30fps, H.264, stereo AAC | 26.6s | iPad 13" |

Both are inside Apple's 15 to 30 seconds and about 28 MB. Recorded with
`tools/trailer.sh --seed 11 --preview` (`--size 886x1920`, and
`--size 1200x1600 --tablet` for the iPad), cut with `tools/previewcut.py`.
Subway isn't in them: a sixth scene would take the take past 30 seconds, and
the screenshot covers it.

**Description: two small edits suggested, not made.** `STORE-LISTING.md` has
an uncommitted edit of yours in it, so it's left alone. These are the two
lines that are now behind the game:

- *UNLOCK AS YOU PLAY*: "...and a few more come from sharing the game"
  could become "...a few more come from sharing the game, and the Subway board
  comes from playing versus."
- The Premium paragraph's "adds eight animated boards" could become "adds
  eight boards that are live 3D scenes". It still names them, which guideline
  2.3.2 wants for paid content.

**The icon** changes with the binary; nothing to upload separately.

---

## Notes for the next person

**`crossplay` still isn't merged into `main`.** It's 30 commits ahead; `main`
has three of its own (the 1.5.5 privacy policy and two invite-page fixes, all
under `docs/`). This build was made with `tools/ship-ios.sh` from a
`crossplay` checkout, which builds that branch.

**Android was not built.** `version/code` is still 1. Its launcher icons were
redrawn to match the new App Store icon, and come out of the same tool.

**Tests.** The whole suite was run on 2026-09-30. Everything passes except
`cloudtest` (3) and `survivaltest` (18), and those fail identically on the
code before this release: the development profile owns Premium, so no ad
break ever comes due. `unveiltest` is new.

**Most test scripts write to the real development profile.** They build the
game scene by hand without moving `Profile.save_path` first, and several
record matches or daily scores. Copy
`~/.local/share/godot/app_userdata/Word Wars/profile.cfg` and its `.bak` aside
before running the suite and copy them back after. The unlock events don't
fire in a hand-built scene (see `reveal_demo` in `game.gd`), so a test run
can't use up the pack's one-time thank-you.
