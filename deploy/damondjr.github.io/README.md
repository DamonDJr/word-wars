# Files for the damondjr.github.io repo

Android only opens the game from `https://damondjr.github.io/word-wars/j/…`
invite links (rather than the browser) if the *domain root* vouches for the
app. That root is the `damondjr.github.io` user-site repo, not this one, so
these files are kept here and copied there.

- `.well-known/assetlinks.json` — Android App Links verification.
- `.nojekyll` — Pages runs Jekyll by default, and Jekyll silently skips
  dot-folders, so without this `.well-known/` is never served. The site is plain
  HTML with no front matter or Liquid, so turning Jekyll off changes nothing
  else.

## The fingerprints

`sha256_cert_fingerprints` must list the certificate that signs the APK the
player actually installed:

1. **Debug** (there now) — `~/.local/share/godot/keystores/debug.keystore`,
   for emulator and sideloaded builds.
2. **Play App Signing key** — add once the app exists in Play Console:
   *Test and release → Setup → App signing → App signing key certificate →
   SHA-256*. Google re-signs every Play download with this key, so without it
   no store install will verify.

Until verification passes, links still work: the page's *Open Word Wars* button
uses the `wordwars://` scheme, which needs no verification.

Check it with:

    adb shell pm get-app-links com.damonj.wordwars

## `play/` — the bio link

`https://damondjr.github.io/play/` redirects straight to the store: the App
Store for iPhone, iPad and desktop, and Google Play for Android once `PLAY_URL`
is set. Until then, Android stays on a page in the site's style. Add `?c=tiktok`
(or `instagram`, `youtube`…) and, once `PROVIDER_TOKEN` is filled in, that tag
reaches App Store Connect as the campaign name. Both constants are at the top
of the page's script.
