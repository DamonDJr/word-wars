Word Wars — macOS (universal)
=============================

Runs on macOS 10.13 High Sierra and newer on Intel, and on any Apple Silicon
Mac. Big Sur is comfortably inside that.


Run it
------
    Unzip it, then drag "Word Wars.app" wherever you keep things.

    The first launch will be refused: "Word Wars.app cannot be opened because
    the developer cannot be verified." That is not a problem with the app —
    it is macOS refusing anything that has not been through Apple's paid
    notarisation, and this build has not.

    Two ways past it, both one-off:

      Right-click the app and choose Open, then Open again in the dialog.

    or, from Terminal:

      xattr -dr com.apple.quarantine "/path/to/Word Wars.app"


On an Apple Silicon Mac
-----------------------
    macOS will not run an unsigned arm64 binary at all, whatever you do with
    quarantine. One command fixes it permanently, and needs no Apple account:

      codesign --force --deep --sign - "/path/to/Word Wars.app"

    That is an ad-hoc signature — it identifies nobody, it just satisfies the
    requirement that the code be signed by someone.


Playing a friend
----------------
Press 2 on the title screen for multiplayer.

  One of you clicks HOST and gets a room code. Click the code to copy it,
  then send it over — Discord, text, whatever.

  The other pastes it into the code field with CTRL+V and clicks JOIN.

Both of you then click READY UP. The match starts when both are ready.

No port forwarding and no IP addresses. Connections are brokered by a public
relay server, so you can be on completely different networks.

If a join hangs, check the code is exactly right — codes are case-sensitive.


New here?
---------
Press 1 on the title screen for PRACTICE, then 1 again for the tutorial.
Seven steps, no opponent, nothing to lose.


Controls
--------
  type letters          build a word
  SPACE / ENTER         fire it
  BACKSPACE             delete a letter
  CTRL+BACKSPACE        clear the line
  ESC                   pause menu / leave match
  H   (title screen)    full rules
  1-5 (title screen)    practice / single player / multiplayer / mastery / settings
  F1                    mute
