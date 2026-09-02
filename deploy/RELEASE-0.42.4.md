# Word Wars 0.42.4 (build 2) — App Store review copy

Three blocks below. The first goes in **App Review Information → Notes**, the
second in **What's New in This Version**, the third in **Promotional Text**.

`0.42.4` is this repository's build track. The App Store marketing version is
set separately at submission; the last released one was 1.0 plus the emote
update.

This is the first submission since `0.36.1`, so What's New covers everything
from `0.37.0` forward: the keyboard work, Survival, the ad curtain, the cloud
save, and the portrait menus. It deliberately does **not** mention
achievements — see *Notes for the next person*.

---

## App Review Notes

> Paste into App Store Connect → App Review Information → Notes.

```
WHAT IS NEW IN THIS BUILD

Four things, three of which can be seen on one device without signing in
to anything.

1. SURVIVAL, a new single-player mode. Tap SURVIVAL on the title screen.
   One board, three lives, no clock; it speeds up until it is not
   survivable and the result is how long you lasted. Nothing gates it —
   no sign-in, no purchase, no tutorial to finish first.

2. The on-screen keyboard was redrawn for thumbs: larger keys, and a tap
   near the boundary between two keys resolves to whichever letter can
   still continue the word being typed. Visible immediately in any match.

3. Adverts now announce themselves. An interstitial used to open with no
   warning, which mid-run was indistinguishable from a crash. The game
   fades up its own AD BREAK curtain first and says what will still be
   there afterwards.

4. Cloud save, which is the one thing a reviewer cannot fully exercise.
   See below.

THE CLOUD SAVE, AND WHAT IT DOES ON A SINGLE DEVICE

Progress is backed up with Apple's Game Center saved games
(GKLocalPlayer.saveGameData) into the player's own iCloud account. There
is no server of ours involved anywhere in this app.

Signed out of Game Center, the Cloud save row in SETTINGS shows a
disabled button and the line "sign in to Game Center to back up your
progress". That is the expected state, not a failure. Signed in, the row
is a single SYNC button that performs a round trip and stays silent when
it succeeds.

The backup contains only what the game already stores on the device:
level, match record, settings, unlocked cosmetics, daily results and
streak, and the Premium pack entitlement. It carries no name, no email
address, no contacts and no location. The only identity attached is the
Apple Account it is stored under, which is Apple's, not ours.

The privacy policy at the support URL describes this in full, under
"Cloud saves".

MULTIPLAYER STILL NEEDS A SECOND PERSON

Tapping VERSUS opens Apple's standard Game Center matchmaking screen
(GKMatchmakerViewController), offering Quick Match and Invite Friends.
With one device and nobody else queued, Quick Match will wait and find
nobody. Every other mode — Practice, Daily, Survival, Solo — is fully
playable alone and is where the game can be assessed.

Emotes, added in the previous release, are likewise only reachable in a
live two-device match and are not drawn at all otherwise.

ADVERTS AND THE PURCHASE

The free version shows an occasional full-screen interstitial between
matches, served by Google AdMob. The single in-app purchase, Premium
pack, removes that break and unlocks three cosmetics that cannot be
earned. RESTORE PURCHASES is in SETTINGS and is reachable whether or not
the pack is owned.

USER-GENERATED CONTENT

There is none. The only free text anywhere in the app is a player's Game
Center display name, which the app shows beside their score and masks
through a profanity filter. Typing input accepts a to z only and is
checked against a fixed dictionary. Blocking and reporting of another
player are handled by Game Center itself.
```

---

## What's New in This Version

> Paste into App Store Connect → What's New in This Version. Limit is 4,000
> characters; this is well under.

```
SURVIVAL — a new mode

One board, three lives, no clock. It opens calm and keeps speeding up
until it is not survivable, and your result is how long you lasted.
There is no finish line, only the point where you go under.

YOUR PROGRESS NOW FOLLOWS YOUR APPLE ACCOUNT

Signed in to Game Center, the game keeps a backup of your record in your
own iCloud account. Lose the phone, replace the phone, sign in on the new
one, and your level, your unlocks and your streak are already waiting.
Nothing is sent to us — there is no server of ours for it to go to.

A KEYBOARD BUILT FOR THUMBS

The on-screen keyboard has been redrawn: bigger keys, a header you can
read, and a tap that lands between two letters now goes to the one that
can actually continue the word you are typing. Fewer words lost to a
near miss.

AD BREAKS ANNOUNCE THEMSELVES

An advert used to arrive with no warning at all — one frame you were
playing, the next you were not, which in the middle of a run read as a
crash. The game now closes its own curtain first and tells you what will
still be there when it lifts. Your run picks up where it left off.

SETTINGS AND MASTERY, REBUILT FOR A PHONE

Both were laid out for a desktop window and sat squashed into the top
half of a phone screen. Rows are now sized for a thumb, the record screen
puts its numbers where you can read them, and the volume sliders can no
longer be set to zero by a tap that missed.

Plus the usual: a dictionary that leans the right way on a boundary, and
a good deal of quiet repair underneath.
```

---

## Promotional Text

> Paste into App Store Connect → Promotional Text. Limit is 170 characters;
> this is 155. Unlike the description, this can be changed without shipping a
> build, so it is the place to put whatever is newest.

```
New: SURVIVAL. One board, three lives, no clock — last as long as you can. And your record now follows your Apple Account to whatever phone you sign in on.
```

---

## Notes for the next person

**Achievements are in the build and deliberately absent from the copy.** All
seventeen are implemented and reporting, but the ids do not exist in App Store
Connect yet, so Apple refuses the whole batch and nothing unlocks. Naming them
in What's New would be advertising a feature that cannot work. `Awards` fails
silently and no screen in the app surfaces it, so nothing looks broken — it
simply does nothing until the ids are entered. See `docs/game-center-setup.md`.

**The survival leaderboard needs creating before this ships**, or the summary
at the end of a survival run has no rank row on it. `com.damonj.wordwars.survival`,
spelled exactly, same document. That one is worth doing even if achievements
wait: it is a single leaderboard, it needs no artwork, and the mode it belongs
to is the headline of this release.

**The privacy policy changed and must be live before review.** iCloud made two
of its sentences false — it claimed progress never leaves the device and that
deleting the app deletes every copy. Both are fixed and a "Cloud saves" section
added. The policy is served from `docs/`, so it only goes live when that is
pushed and Pages has rebuilt. Check the support URL in a browser before
submitting.

**Do not tap your own adverts on this build.** iOS ships the live unit
(`LIVE_UNIT_IOS` in `scripts/ads.gd`) and `TEST_DEVICES` is still empty, so a
developer testing a build is indistinguishable from click fraud as far as
AdMob is concerned. Register the device id first — the SDK prints it on the
first request, in a line containing `setTestDeviceIds`.

**Ad frequency roughly doubled in 0.39.0**, from every three to five matches
down to every two to three. That is not in What's New, because nobody
announces more adverts, but it is the change most likely to show up in reviews
of this version. Worth knowing where it came from if the rating moves.
