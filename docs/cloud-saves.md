# Cloud saves

The profile — level, cosmetics, daily streak, survival records, the premium pack
— is mirrored into **Game Center saved games**, which are stored in the player's
iCloud. A player who uninstalls, upgrades, or loses their phone signs into the
same Apple ID and gets it back. No login screen, no account, no server of ours.

The code is `scripts/cloud.gd` (autoload `Cloud`) and the merge is
`Profile.merge_from`. Both are commented at length; this file is only the part
that is not code.

## What has to be done outside the repo

This is the whole of it, and until all four are true the game runs exactly as it
did before — local saves, and the Settings row reports that iCloud is not
reachable.

1. **Enable iCloud on the App ID.** developer.apple.com → Certificates,
   Identifiers & Profiles → Identifiers → `com.damonj.wordwars` → tick
   **iCloud**, with **CloudKit** support (Game Center saved games are stored in
   an iCloud Documents container).
2. **Create the container** `iCloud.com.damonj.wordwars`, and assign it to that
   App ID. The name must match `entitlements/additional` in
   `export_presets.cfg` exactly.
3. **Regenerate the provisioning profile** `Word Wars App Store Distribution`.
   An existing profile does *not* pick up a new capability — it has to be
   rebuilt and re-downloaded, or signing fails with
   `Provisioning profile ... doesn't include the
   com.apple.developer.icloud-container-identifiers entitlement`.
4. **Update the CI secret** holding that profile
   (`.github/workflows/ios.yml`, the `BUILD_PROVISION_PROFILE_BASE64` step) with
   the regenerated one.

Nothing in App Store Connect needs a saved-games record the way leaderboards and
achievements do — there is no id to configure and no dashboard to fill in.

## The entitlement

Already in `export_presets.cfg` under `entitlements/additional`:

```xml
<key>com.apple.developer.icloud-container-identifiers</key>
<array>
	<string>iCloud.com.damonj.wordwars</string>
</array>
<key>com.apple.developer.ubiquity-container-identifiers</key>
<array>
	<string>iCloud.com.damonj.wordwars</string>
</array>
<key>com.apple.developer.icloud-services</key>
<array>
	<string>CloudDocuments</string>
</array>
```

The iOS workflow fails the build if the signed app comes out without it, because
the alternative is an IPA that installs, runs, and silently never syncs — a
failure whose only symptom is a player, months later, saying they lost
everything.

## Checking it on a device

Settings has a **Cloud save** row on any Apple build. It says when the last sync
happened and syncs on demand. The device log carries the rest: every failure in
`cloud.gd` is a `push_warning` naming what Apple refused.

To test a restore properly you have to actually delete the app — a reinstall
over the top keeps `user://profile.cfg` and proves nothing. Play a few matches,
watch the row say it saved, delete the app, reinstall, and the record screen
should come back on first launch.

## Two things worth knowing before changing any of this

**A merge only ever moves numbers up.** Lifetime totals are maxed rather than
summed, because the two copies are two views of the same history and adding them
double-counts every match on every launch. The cost is that playing on two
devices in parallel keeps the larger side rather than the sum. The reasoning is
written out above `Profile.merge_from`; `tools/cloudtest.gd` holds it to it
across forty random pairs.

**Nothing uploads before it has downloaded.** A fresh install has a blank
profile, and pushing that first would overwrite the only copy of the record with
nothing. `Cloud.push` refuses until a `pull` has completed in this session. That
one line is the difference between this feature and a way to lose a save.

```bash
godot --headless --script tools/cloudtest.gd
```
