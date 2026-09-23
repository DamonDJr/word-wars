# Word Wars 0.51.1 (build 4) — App Store review copy

Three blocks below. The first goes in **App Review Information → Notes**, the
second in **What's New in This Version**, the third in **Promotional Text**.
Before any of them, **App Privacy has to be updated** — see that section; it is
the one part of this submission that is not copy.

`0.51.1` is this repository's build track. The App Store marketing version for
this submission is **1.5.5**.

Both sides checked against App Store Connect on 2026-09-23 rather than assumed:

```bash
asc versions list --app 6802900966
asc builds list --app 6802900966 --limit 5
```

| | Binary | Listing | State |
|---|---|---|---|
| Previous | `0.51.0` build 1 | **1.5.1** | `READY_FOR_SALE`, created 2026-09-21 |
| This one | `0.51.1` build 4 | **1.5.5** | uploaded from `crossplay` at `1bf2ff3` |

**1.5.2 to 1.5.4 do not exist.** The listing jumps 1.5.1 → 1.5.5 on the author's
call; nothing was submitted under the numbers in between.

## Which build to submit

**Build 4.** It is the only 0.51.1 build with everything below in it.

| Build | What it is | Submit? |
|---|---|---|
| 1 | never uploaded — refused at App Store Connect with ITMS-90208 | — |
| 2 | first build with the EOS frameworks packaged correctly | no |
| 3 | adds invite links that open the game (`wordwars://`) and Paste | no |
| 4 | adds the new board effects and the phone Cosmetics screen | **yes** |

Build 1's rejection is worth knowing about: EOSG's iOS library is a bare
`.dylib`, Godot wraps it in a framework whose Info.plist claimed iOS 14 around a
binary built for iOS 15, and Apple refuses a bundle whose plist claims less than
its binary. The iOS workflow now rewrites each generated framework's
`MinimumOSVersion` from its own binary and fails the build on any mismatch.

## What this release covers

| Change | Who gets it | Kind |
|---|---|---|
| Versus runs on Epic Online Services — ready to play Android when it launches | everyone | feature |
| Invite a friend by link or five-character room code; Join with a code; Paste | everyone | feature |
| Keyboard: a key bubble above your thumb, and it learns where your thumbs land | everyone | feature |
| Four premium boards' effects rebuilt: Volcano, Space, Clouds, Forest | premium | polish |
| Cosmetics screen redesigned for phones | everyone | polish |
| Share button shows progress toward the next share reward; the card returns every few days | everyone | polish |
| Versus lobby Back button fixed in landscape — desktop builds only; phones and iPads are portrait | desktop | fix |

**What changed underneath versus.** Matchmaking moved off Game Center onto Epic
Online Services, so the same pool can include Android players once the Android
version ships. Game Center still signs the player in and still owns
leaderboards, achievements and cloud saves; only matches moved. Sign-in to Epic
is anonymous (Device ID — no Epic account, no login screen), happens only when a
player opens versus, and matches are routed through Epic's relays, so players
never see each other's IP address.

---

## App Privacy — update before submitting

1.5.1's answers were built on "the app makes no network requests of its own".
That is no longer true for versus, so App Privacy needs a look. Epic is a
third-party SDK, and Apple counts what a third-party SDK collects.

What Epic receives, from `multiplayer_manager.gd` and `hauth.gd`:

- a **product user ID**, random, created at sign-in and replaced every launch;
- the **device model and OS** string, sent with that sign-in;
- the **IP address**, as any network service sees it;
- the room code and the match packets, relayed in real time and not retained.

Suggested answers — a judgement, so check it against Apple's definitions:

| Data type | Collected? | Linked to identity? | Tracking? | Purpose |
|---|---|---|---|---|
| Identifiers → **User ID** | Yes (Epic) | **No** — random, per session | No | App Functionality |
| Usage Data / Gameplay Content | No — relayed, not stored | — | — | — |
| Location | No — IP is not used to locate | — | — | — |

The AdMob answers from earlier releases stand unchanged. Add Epic's privacy
policy URL (`https://www.epicgames.com/site/privacypolicy`) wherever App Store
Connect asks about third parties.

**Export compliance:** EOS uses TLS and DTLS, which is standard encryption and
exempt, the same as the HTTPS the ad SDK already used. If the build asks, the
answer is unchanged from previous builds.

**The privacy policy is live and matches this build** — see the last section.

---

## App Review Notes

> Paste into App Store Connect → App Review Information → Notes. Limit is
> 4,000 characters.

```
No new permissions, no new in-app purchase products, and no change to
the price, the advertising SDK, the share rewards, or the
user-generated content answers given at the last review (1.5.1).

WHAT CHANGED

Versus matches against other players now run on Epic Online Services
(EOS) instead of Game Center matchmaking. This is so iPhone players can
be matched with players on our Android version, which is in testing.
Game Center is still used for sign-in, leaderboards, achievements and
cloud saves; only matchmaking moved.

EPIC ONLINE SERVICES, AND WHAT IT RECEIVES

The app signs in to EOS anonymously, using EOS's Device ID login. There
is no Epic account, no login screen, no email and no password. It
happens only when a player opens VERSUS and starts a match; the rest of
the game never contacts Epic. Epic receives a random ID created for that
session, the device model string, the IP address, and the match data
passed between the two players. Matches are relayed through Epic's
servers so the two players never see each other's IP address. The
privacy policy and our App Privacy answers are updated for this.

INVITES, ROOM CODES AND THE CLIPBOARD

VERSUS > INVITE A FRIEND opens a room with a five-character code and
shows the system share sheet with a link to a page on our GitHub Pages
site. The page shows the code and a button that copies it and opens the
app through the wordwars:// URL scheme. VERSUS > JOIN WITH A CODE accepts
the code typed on the game's keyboard, or via a PASTE button. The app
reads the clipboard only when PASTE is pressed, and only looks for a
room code in it.

HOW TO TEST ON ONE DEVICE

VERSUS > CPU MATCH works with no account and no second player. QUICK
MATCH and room codes need a second device running the app; with one
device, QUICK MATCH searches, shows how long it has been looking, and
after a short wait offers a CPU match instead. INVITE A FRIEND opens a
room and shows the share sheet, which can be dismissed; the room code
is shown on screen.

Practice, Daily, Weekly, Survival and Solo are unchanged and fully
playable with no account and no network, on iPhone and on iPad.

OTHER CHANGES

The on-screen keyboard shows the pressed letter above the thumb, and
adapts to where the player's taps land, from averages stored on the
device. Four purchasable board themes have new animated backgrounds.
The Cosmetics screen is laid out for phones. None of these add data
collection or permissions.

USER-GENERATED CONTENT, THE PURCHASE, ADVERTS AND CLOUD SAVE

Unchanged from the last review. There is no field anywhere in this app
where a player types text another player can see. The opponent's label
in a match is their Game Center display name, drawn through the game's
profanity filter. The single in-app purchase removes adverts and
unlocks cosmetics; RESTORE PURCHASES is in SETTINGS.
```

*(About 2,900 characters.)*

---

## What's New in This Version

> Paste into App Store Connect → What's New in This Version. Limit is 4,000
> characters.

```
PLAY YOUR FRIENDS, WHEREVER THEY ARE

Versus has a new engine underneath it, built for playing across
devices — and ready for Android players when Word Wars arrives there.

• Invite a friend with a link. Send it through Messages, WhatsApp,
  anything. They tap it, the game opens, and you're in the same room.
• Or share a five-character room code and have them type it in.

A KEYBOARD THAT LEARNS YOUR AIM

• The letter you press now pops up above your thumb, so you can see a
  mistap the moment it happens.
• The keyboard learns where your thumbs actually land and quietly
  adjusts to you. The more words you play, the better it fits.

PREMIUM BOARDS, REPAINTED

• Volcano: embers that rise, glow and burn out.
• Space: stars that shimmer, and the odd shooting star.
• Clouds: real cumulus drifting across the sky.
• Forest: falling leaves and sunbeams with dust in the light.

ALSO NEW

• The Cosmetics screen is rebuilt for phones: every category one tap
  away, a big live preview, and pictures on every board and block.
• The Share button tells you what your next share unlocks.
```

---

## Promotional Text

> Paste into App Store Connect → Promotional Text. Limit is 170 characters.
> Changeable without shipping a build.

```
Invite a friend with a link and play in seconds. Plus a keyboard that learns your aim, and premium boards with glowing embers and shimmering stars.
```

*(147 characters.)*

---

## Screenshots and previews

**Worth refreshing, but not blocking.** Versus looks different (four doors
instead of three), the Cosmetics screen is new, and the premium boards animate
differently — none of which a still screenshot shows well. The outstanding
items from `RELEASE-0.49.0.md` still stand.

---

## The privacy policy

`docs/privacy.html` on `main` is what `https://damondjr.github.io/word-wars/privacy.html`
serves, and it was updated to match this build **before** submission:

- a new section, *Online versus — Epic Online Services*: what Epic receives, the
  relays, invite links, and a link to Epic's policy;
- *The clipboard*: read only when Paste is pressed, only for a room code;
- *How you type*: the per-thumb tap averages, stored with settings, backed up in
  the player's own cloud save and nowhere else;
- Game Center's section now lists leaderboards, achievements and cloud saves,
  since matches no longer run on it.

It was committed to `main` separately from the code, because GitHub Pages serves
`main` and the code is still on `crossplay`. **Merging `crossplay` into `main`
will conflict-free carry the same file.**

---

## Notes for the next person

**The code is on `crossplay`, not `main`.** This build was made by
`tools/ship-ios-crossplay.sh` (uncommitted, deliberately — delete it after the
merge). Merge `crossplay` once 1.5.5 is approved, and go back to
`tools/ship-ios.sh`.

**An App Store build now makes network requests to Epic.** Every earlier
release's review notes said the app had no server and made no requests of its
own; that stops being true here, only for versus. Anything that repeats the
old line — support replies, the next review's notes — needs correcting.

**The iOS build cannot receive the invite link itself.** Godot does not pass
`openURL` to scripts, so on iPhone the page copies the code and the game's Paste
button picks it up. Android does receive the link and joins directly. A
GDExtension handling `application(_:open:)` would close the gap on iPhone.

**Messenger, Instagram and Facebook's in-app browsers cannot open apps on iOS.**
The invite page detects them and switches to a copy button with instructions.
On Android the page uses an `intent://` link, which those browsers do follow.

**Android-only fixes in this code do nothing on iOS**, but are here so the two
stay one codebase: the back gesture now behaves as Escape instead of quitting,
haptics have the VIBRATE permission, and the premium card is not shown where
there is no store.

**Tests.** `aimtest` is new and passes. `cloudtest` still has its three
pre-existing failures and `survivaltest` its seventeen (the development profile
owns Premium); neither is touched by this release. `challengetest` writes a fake
daily score into the real development profile — back it up before running it.
