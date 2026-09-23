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
