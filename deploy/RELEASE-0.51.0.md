# Word Wars 0.51.0 (build 1) — App Store review copy

Three blocks below. The first goes in **App Review Information → Notes**, the
second in **What's New in This Version**, the third in **Promotional Text**.

`0.51.0` is this repository's build track. The App Store marketing version for
this submission is **1.5.1**.

**The two numbers are different on purpose.** The listing runs on `1.x.y` and the
binary on `0.4x.y`, and Apple's higher-version check applies to the binary. Both
sides were checked against App Store Connect rather than assumed this time:

```bash
asc versions list --app 6802900966
asc builds pre-release-version view --app 6802900966 --latest
```

| | Binary | Listing | State |
|---|---|---|---|
| Previous | `0.49.0` build 4 | **1.5.0** | `READY_FOR_SALE`, created 2026-09-20 |
| This one | `0.51.0` build 1 | **1.5.1** | uploaded, free on both tracks |

`1.5.0` went out as planned — unlike the `0.48.0` → `1.5.0` claim that this
document's predecessor had to correct. It is live and is what players have now,
so this is a patch on top of it rather than a first submission of that content.

**`0.50.0` does not exist and never did.** Nothing was built against it; the
track went `0.49.0` → `0.51.0` on the author's call. Worth knowing before
somebody goes looking for the missing release document.

## Which build to submit

**Build 1.** It is the only build against `0.51.0`.

## What this release covers

One change. Everything else is `1.5.0` untouched — no new content, no new
purchase, no change to how the game plays.

| Change | Who gets it | Kind |
|---|---|---|
| A shared result arrives as a card with a score on it, not a bare link | everyone | fix |

**What was wrong.** The game composed a 1080×1920 card and a written line and
handed both to the system share sheet, which is correct and is what shipped.
But Facebook, Threads and LinkedIn do not read either: they find the URL inside
the shared text, fetch it, render whatever that page says about itself, and
discard the sentence and the picture. The URL was the App Store listing, and
what a store listing says about itself is a grey box with an app name in it. So
a share that had a whole file's worth of composition behind it arrived as a
link and nothing else.

**What changed.** The link now points at a page on the project's own GitHub
Pages site instead of the store. That page carries `og:` tags and a 1200×630
preview image, so the same scrape now produces a card with the game's name, a
row of letter tiles and a line of copy on it. Tapping it still lands on the App
Store.

**Nothing about the share rewards changed.** Still one share per calendar day,
still a list of dates in the player's own local save file, still no attribution
of any kind. The ladder and the three cosmetics behind it are exactly as
reviewed for `1.5.0`.

---

## App Review Notes

> Paste into App Store Connect → App Review Information → Notes. Limit is
> 4,000 characters.

```
No new permissions, no new in-app purchase products, and no change to
the price, the advertising SDK, the data collected, the share rewards,
or the user-generated content answers given at the last review (1.5.0).

WHAT CHANGED

There is one change in this build. When a player shares a result, the
link that travels with it now points at a page we publish instead of
pointing at the App Store listing. This is presentation only: the
previous link produced an untitled grey box in social apps, and the new
one produces a preview card showing the game.

THE APP MAKES NO NETWORK REQUEST TO THAT PAGE. It composes a URL as text
and places it in the message next to the image. Nothing is fetched,
posted or uploaded by the app, and the app never learns whether anyone
opened the link. If a recipient does open it, their own browser loads a
static file from GitHub Pages. There is no server of ours anywhere in
this, and no code of ours runs on the page beyond reading the numbers
out of the address bar to display them.

WHAT THE LINK CONTAINS. The score or the survival time, which mode was
played, the best word of the match, and a short badge line such as "new
personal best" or "7 day streak". On a run played against a challenge
the badge can name the player who set that challenge, taken from their
Game Center display name and passed through the game's profanity filter.
There is no identifier, no account, no device information, no advertising
ID, and nothing that distinguishes one sender from another.

THE SHARE REWARDS ARE UNCHANGED. Three cosmetic items still unlock after
the system share sheet has reported completion on 3, 8 and 15 separate
calendar days. The app still records only a list of dates, in the
player's own local save file, and still does not know, record or
transmit where a share went, what was in it, who received it, or
whether anyone opened it. At most one share counts per calendar day.

ASSESSING IT ON ONE DEVICE, SIGNED OUT

Unchanged from 1.5.0. Practice, Daily, Weekly, Survival and Solo are
fully playable with no account and no network, on iPhone and on iPad.
VERSUS opens our lobby and CPU Match works with no account. BOARDS is
reachable and explains itself when signed out.

To see the change itself: finish any match, then SHARE on the results
screen. The system share sheet opens with the result card attached.

USER-GENERATED CONTENT, THE PURCHASE, ADVERTS AND CLOUD SAVE

All unchanged from the last review. There is no field anywhere in this
app where a player types a name another player can see. Typing input
accepts a to z only and is checked against a fixed dictionary.
Leaderboards show Game Center display names, sourced from Game Center
and drawn through the game's profanity filter. Blocking and reporting
are handled by Game Center. The single in-app purchase removes adverts
and unlocks cosmetics; RESTORE PURCHASES is in SETTINGS whether or not
it is owned. Progress is backed up with Apple's Game Center saved games
into the player's own iCloud account.
```

---

## What's New in This Version

> Paste into App Store Connect → What's New in This Version. Limit is 4,000
> characters.

```
SHARING, FIXED

Share a run and it now arrives as something worth looking at: your
score, your best word of the match, and the board it came off, drawn
as a card.

It used to go out as a plain link. Most apps threw away the picture and
the words and showed a blank box with the app's name in it, which is
not much of a way to challenge somebody.

Everything else is unchanged from 1.5.0.
```

---

## Promotional Text

> Paste into App Store Connect → Promotional Text. Limit is 170 characters.
> Changeable without shipping a build, so it carries whatever is newest.

**`1.5.0`'s promotional text is still accurate and can be left alone** — eight
boards, weekly missions and the duck are all still the newest content, and a
bug fix is not what this field is for. If it is being changed anyway:

```
Beat a friend's score and send them the proof — your best word, your run, and the board it came off, as a card they can actually see.
```

*(133 characters.)*

---

## Screenshots and previews

**No refresh needed for this release.** Nothing visible in the game changed, and
the card that changed is not something a listing visitor sees.

Everything outstanding in `RELEASE-0.49.0.md` still stands and is not addressed
here: the screenshot set still shows the old wash themes rather than the nine
painted boards, eight of the nine backgrounds are still the soft 328×590 slices,
and app previews are still blocked on the two problems named back in `0.47.0`.

---

## Notes for the next person

**A share now carries another player's display name into a URL, where it used
to only be in the picture.** On a challenge run the badge reads "beat <name>'s
challenge", and that string goes into the query string of the shared link. It
was already in the shared *image* — the versus card has always drawn the
rival's name in a stats cell — so this is not new information leaving the
device, but it is a new *form* of it: a URL gets pasted, forwarded and logged
by whatever handles it, and a picture does not. `_show_name` runs it through
the profanity filter, but only when `fx_censor` is on, and that is a switch in
SETTINGS the player can turn off.

Dropping the badge from the URL when it contains a name is a two-line change in
`_share_url()`. It was left in deliberately — the badge is the most persuasive
line on the page, and the sharer is knowingly posting about that person — but
it is the first thing to reconsider if this ever draws a question.

**The preview image cannot carry the player's actual score, and this is
structural.** A link preview is composed on Facebook's servers from a static
file, and GitHub Pages has no request-time renderer. So `docs/s/og/*.png` are
per mode and verdict — six of them — and the real numbers travel in the query
string for whoever taps through. Anyone wanting "14,320" in the *preview* needs
a Cloudflare Worker or equivalent in front of the site, which is a genuine
piece of infrastructure rather than a tweak.

**The pages are committed, not generated at build time.** `tools/ogcards.gd`
writes both the images and the HTML into `docs/s/`, and what is in git is what
GitHub Pages serves. Change the copy in the `PAGES` table, re-run it, commit
what falls out. Do not hand-edit the HTML; it will be overwritten.

**Every social platform caches previews per URL.** Facebook, LinkedIn and the
rest will keep serving whatever they scraped first, so a copy change is not
live until each one is told to re-scrape — Facebook's Sharing Debugger and
LinkedIn's Post Inspector both do it by hand, one URL at a time.

**Instagram is still not fixed and cannot be from here.** It refuses pre-filled
text by policy whatever is handed to it. The only thing that would help is
rebuilding the iOS share plugin around `UIActivityItemSource` so each target
gets a different item, plus `LPLinkMetadata` for the sheet's own header. The
plugin ships as a prebuilt `.xcframework` in `ios/plugins/`; the source is
cengiz-pz's, and changing it needs a Mac.

**`docs/` is now `.gdignore`d.** Godot imports anything under the project root,
and with `export_filter="all_resources"` those six preview PNGs would have been
packed into the app — most of a megabyte shipped to every player so that
Facebook could fetch them off a web server. Same trap as `scripts/Documents/`.
Anything added under `docs/` from now on stays out of the build, which is
correct for a website but worth knowing if something there is ever genuinely
needed at runtime.

**`sharetest.gd` is not in `tools/build.sh`.** It covers the part most likely to
rot — that every slug the game can produce has a page and a preview image behind
it, and that `share.gd` and `ogcards.gd` still agree on the site root — but
nothing runs it automatically, so a missing page would ship as a 404 where the
preview should be. Adding it to the gate is one line; it was left out because
the existing gate is a deliberate subset.

**`cloudtest` still has its three pre-existing failures** around what the cloud
row says after a restore, and **`survivaltest` still has seventeen** from the
development profile owning the Premium pack. Both were confirmed present before
this release and neither is touched by it.
