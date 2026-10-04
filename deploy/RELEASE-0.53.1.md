# Word Wars 0.53.1 (build 4): App Store review copy

A small release with two fixes, both to versus: an invite link opens the game
straight into the friend's room on iPhone, and a match one player leaves
partway through no longer crashes or strands the other. Two blocks below: the
first goes in **App Review Information → Notes**, the second in **What's New
in This Version**.
The **Promotional Text**, **screenshots** and **App Previews** stay as they
are.

`0.53.1` is this repository's build track. The App Store marketing version is
**yours to pick, and no version exists for it in App Store Connect yet**.
**1.6.1** is the suggestion: fixes to an existing feature, nothing new to sell
or show.

Checked against App Store Connect on 2026-10-04:

```bash
asc versions list --app 6802900966
asc builds list --app 6802900966 --limit 8
asc versions view --version-id 192323c5-de61-4459-bf16-13f4e429a2bd --include-build --output table
```

| | Binary | Listing | State |
|---|---|---|---|
| Previous | `0.53.0` build 6 | **1.6.0** | `READY_FOR_SALE`, created 2026-09-30 |
| This one | `0.53.1` build 4 | **1.6.1**, suggested | `VALID`, uploaded 2026-10-04 from `crossplay` at `2e2d91e` |

## Which build to submit

**Build 4.** It's the only one with both fixes, and build 2 has a board in it
that isn't ready to ship.

| Build | What it adds | Submit? |
|---|---|---|
| 1 | invite links open the room on iPhone | no |
| 2 | Atlantis, a rendered board, as a free board (a TestFlight look) | **no** |
| 3 | Atlantis held back again | no |
| 4 | leaving a versus match partway through: no crash, no stranded opponent | **yes** |

## What this release covers

| Change | Who gets it | Kind |
|---|---|---|
| A versus invite link opens the game straight into the friend's room on iPhone | everyone on iPhone | fix |
| A versus match one player leaves partway through: no crash, and the other is told within seconds | everyone | fix |

**How it works.** iOS has always opened the game from a `wordwars://` link
(the scheme was registered in 1.6.0), but the engine never passed the link
on, so the game started at the title and the room code had to travel on the
clipboard and be pasted by hand. The Deeplink plugin (godot-mobile-plugins
v6.0.1, iOS half only, in `ios/plugins/`) now catches the link both when it
launches the game and while the game is running, and hands it to the same
`offer_code` path Android has always used. A link is taken once and then
cleared, because a link that launched the game arrives twice (the check at
launch and the plugin's queued signal) and would otherwise join twice.
`versustest` covers the link shapes and the take-once. Android is unchanged:
it already went straight to the room.

**Leaving a match partway through.** Reproduced on Linux with two copies of
the game playing a real match over Epic (`multiplayer_manager.gd`):

- *The crash.* After a match whose opponent vanished, the app segfaulted on
  its way out: Epic's SDK was never shut down, so one of its threads was still
  running when Godot unloaded the extension. Desktop quits and Android's back
  gesture off the title both hit it; an iPhone app is killed outright and never
  runs that code. Epic is now released and shut down in `_exit_tree`.
- *The goodbye.* Leaving sends a `bye`, but the connection was freed the
  instant it was closed, so the `bye` was usually lost and the other player
  found out the slow way. A closed connection is now held for a second, then
  closed, then let go, which also means it can't be freed inside its own update.
- *The slow way.* With no `bye`, the other player played on against a frozen
  board until Epic noticed: 35 seconds to two and a half minutes, measured.
  Both ends now send a heartbeat every two seconds and end the match after ten
  seconds of silence, so a killed phone's opponent wins in about ten. Armed
  only once the other end has sent one, so a 1.6.0 opponent, which never will,
  gets the old behaviour rather than being dropped.
- *Backgrounding.* The app going into the background mid-match now leaves it,
  as the pause menu's Leave does: the opponent wins at once, and the player
  comes back to the title. Before, they came back to a dead match and were
  declared its winner when it finally failed. Epic is also now told when the
  app goes into the background and comes back, as it asks mobile games to do.

| How a player left | The other player, before | Now |
|---|---|---|
| Pause menu Leave | usually found out the slow way | wins at once |
| App closed or connection lost | 35s to 2.5 min on a frozen board | wins in about 10s |
| App sent to the background | the same, and the leaver "won" on return | wins at once; the leaver is at the title |

`versustest` covers the heartbeat; `gctest` knows the new `going_away` signal.

**The invite page is not live yet.** The page a shared link opens
(`docs/j/index.html`) changed with this: on iPhone its button reads "Open Word
Wars" instead of "Copy code & open Word Wars", and if the page is still in
front 2.5 seconds after the tap (nothing opened, so the game isn't
installed), the App Store becomes the main button. GitHub Pages serves the
site from `main/docs`, and this change is only on `crossplay`, so players see
the old page until `docs/j/index.html` is copied to `main`. It's safe to
publish before or after 1.6.1 is out: the button still copies the code as it
opens the game, so a 1.6.0 install that opens to the title can paste it as
before.

---

## App Privacy: no change

Nothing new is collected or sent. The room code that used to come from the
clipboard now comes from the link that opened the app; it's used only to join
that room, exactly as before. The heartbeat is a packet with no content beyond
its type, sent over the match's existing Epic connection. The live policy
already covers invite links and the clipboard (1.5.5).

**Export compliance:** unchanged.

---

## App Review Notes

> Paste into App Store Connect → App Review Information → Notes. Limit is
> 4,000 characters.

```
No new permissions, no new in-app purchase products, and no change to
the price, the advertising SDK, the data collected, the network use,
the share rewards, or the user-generated content answers given at the
last review (1.6.0).

WHAT CHANGED

Two fixes to versus matches.

Invite links: when a player invites a friend to a versus match, the
friend gets a link. On iPhone, tapping that link opened Word Wars but
left the friend on the title screen, where they had to paste the room
code by hand. The app now reads the link it was opened with and goes
straight into the friend's room. The app's link scheme (wordwars://)
is the same one registered in 1.6.0; only its handling is new.

Leaving a match: when one player left a versus match partway through,
the other could be left playing against a frozen board for a minute
or more, and the app could crash afterwards. Now the remaining player
is told within seconds and wins. Sending the app to the background
during a versus match now counts as leaving it.

HOW TO SEE THE CHANGES

Both need two devices. Invite links: On the first, open VERSUS and tap Invite a
friend: the app opens a room and the share sheet with a link. Send the
link to the second device (Messages works) and tap it there. It opens
the game's invite page in Safari; tap its button to open Word Wars,
which now goes straight into that room, and the match starts when both
players are in. Typing the room code into VERSUS > Join with a code
still works as before.

Leaving a match: in a versus match on two devices, go to the Home
Screen on one of them. The other is told the player left and wins
straight away. Force-quitting one instead, the other wins within
about ten seconds.

VERSUS, ACCOUNTS, ADVERTS AND CLOUD SAVE

Unchanged from 1.6.0. Versus still runs on Epic Online Services with
anonymous Device ID sign-in. There is no field anywhere in the app
where a player types text another player can see. RESTORE PURCHASES
is in SETTINGS.
```

*(About 2,000 characters.)*

---

## What's New in This Version

> Paste into App Store Connect → What's New in This Version. Limit is 4,000
> characters.

```
FASTER VERSUS INVITES

Tap a friend's invite link on your iPhone and Word Wars opens straight
into their room. No more copying a code and pasting it in.

FIXES

If your opponent leaves a versus match partway through, by quitting,
closing the app or losing their connection, you now find out within
seconds and take the win, instead of playing on against a frozen board.

Fixed a crash that could follow a versus match the other player left.
```

---

## The listing

**Promotional Text: keep 1.6.0's.** It's about the 3D boards and Subway,
which are still the news.

**Screenshots and App Previews: unchanged.** Nothing on screen is different.

---

## Notes for the next person

**Atlantis is in this binary, hidden.** Its theme, art and scene are wired
(`Cosmetics.THEMES`, `BOARD_3D` in `game.gd`, the plate path in
`board3d.gd`) but it has no row in the theme catalogue (`profile.gd`), so
nobody can see or equip it. Anyone who equipped it in TestFlight build 2
falls back to Midnight: `worn` and `equip` now ignore an id that isn't in the
catalogue, where before an unknown id passed as unlocked. Its files ride
along in the bundle, about 13 MB imported for iOS (the plate and its depth map
are most of it). Adding `boards/3d/atlantis/*, boards/3d/atlantis.glb,
boards/3d/previews/atlantis.jpg` to the iOS preset's `exclude_filter` would
leave them out until it ships; nothing can load them while the catalogue row
is missing.

**`crossplay` still isn't merged into `main`.** This build was made with
`tools/ship-ios.sh` from a `crossplay` checkout, which builds that branch.

**Android was not built.** The leaving-a-match fixes apply there too (the
crash on quitting reaches Android players through the back gesture), so an
Android build of this is worth making. The invite-link change is iOS only.

**Tests.** The whole suite was run on 2026-10-04 against build 4's code.
Everything passes except
`cloudtest` (3) and `survivaltest` (18), the same known failures as 0.53.0:
the development profile owns Premium, so no ad break ever comes due. Copy
`~/.local/share/godot/app_userdata/Word Wars/profile.cfg` and its `.bak` aside
before running the suite and copy them back after.
