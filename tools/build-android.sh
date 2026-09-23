#!/usr/bin/env bash
# Build the signed Play Store bundle: build/android/WordWars.aab.
#
#   tools/build-android.sh
#
# Signed with your *upload key*. Play re-signs every download with its own app
# signing key (Play App Signing), so the key here only has to prove the upload
# came from you — and if it is ever lost, Play support can reset it.
#
# The key's details are never in this repo. They come from the environment, the
# names Godot reads itself, usually set by sourcing a file kept outside it:
#
#   ~/.config/wordwars/android-release.env   (chmod 600)
#     export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$HOME/.config/wordwars/upload.keystore"
#     export GODOT_ANDROID_KEYSTORE_RELEASE_USER="upload"
#     export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="…"
#
# Every upload to Play needs a higher version code than the last, and Play
# refuses a repeat outright, so the code in export_presets.cfg (the Android
# preset's version/code) is checked against what you say was uploaded last:
#
#   LAST_CODE=3 tools/build-android.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"
ENV_FILE="${ANDROID_RELEASE_ENV:-$HOME/.config/wordwars/android-release.env}"
OUT="build/android/WordWars.aab"

if [[ -z "${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:-}" && -f "${ENV_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
fi
for v in GODOT_ANDROID_KEYSTORE_RELEASE_PATH GODOT_ANDROID_KEYSTORE_RELEASE_USER \
    GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD; do
  [[ -n "${!v:-}" ]] || { echo "FAILED: $v is not set — see the top of this script." >&2; exit 1; }
done
[[ -f "${GODOT_ANDROID_KEYSTORE_RELEASE_PATH}" ]] \
  || { echo "FAILED: no keystore at ${GODOT_ANDROID_KEYSTORE_RELEASE_PATH}" >&2; exit 1; }

# The Android preset's version, read from the section that belongs to it.
read -r CODE NAME < <(python3 - <<'PY'
import re
text = open("export_presets.cfg").read()
# The quote after Android is what keeps "Android (emulator)" from matching.
start = text.index('name="Android"')
# From that preset's options onward; the first match below is therefore its own.
opts = text[text.index(".options]", start):]
code = re.search(r"^version/code=(\d+)", opts, re.M).group(1)
name = re.search(r'^version/name="([^"]*)"', opts, re.M).group(1)
print(code, name)
PY
)
echo "==> Word Wars ${NAME} (version code ${CODE})"
if [[ -n "${LAST_CODE:-}" && "${CODE}" -le "${LAST_CODE}" ]]; then
  echo "FAILED: version code ${CODE} is not above the last upload (${LAST_CODE})." >&2
  echo "        Raise version/code in the Android preset first." >&2
  exit 1
fi

[[ -d addons/epic-online-services-godot/bin/android ]] || tools/fetch-eos.sh android
tools/android-template.sh

echo "==> Exporting"
mkdir -p build/android
rm -f "${OUT}"
godot --headless --path . --export-release "Android" "${OUT}" > build/android/export.log 2>&1 || {
  echo "FAILED: export failed — the end of build/android/export.log:" >&2
  grep -a -A8 "went wrong" build/android/export.log >&2 || tail -20 build/android/export.log >&2
  exit 1
}
[[ -f "${OUT}" ]] || { echo "FAILED: the export wrote no ${OUT}" >&2; exit 1; }

# What went in, checked rather than assumed: signed, arm64 only, EOS aboard,
# and the dictionary present — the same failure that once shipped a game that
# rejected every word.
echo "==> Checking the bundle"
jarsigner -verify "${OUT}" > /dev/null || { echo "FAILED: the bundle is not signed." >&2; exit 1; }
LIST="$(unzip -l "${OUT}")"
grep -q "base/lib/arm64-v8a/libEOSSDK.so" <<<"${LIST}" \
  || { echo "FAILED: EOS is not in the bundle — cross-play would be missing." >&2; exit 1; }
if grep -q "base/lib/x86_64/" <<<"${LIST}"; then
  echo "FAILED: x86_64 libraries are in the bundle — that is the emulator preset." >&2; exit 1
fi
# In a bundle Godot puts the game's files in an install-time asset pack, not in
# base/, which is why this is matched by its tail.
grep -q "/assets/data/words.txt$" <<<"${LIST}" \
  || { echo "FAILED: data/words.txt is not in the bundle." >&2; exit 1; }

SIZE=$(du -h "${OUT}" | cut -f1)
echo "==> ${OUT} (${SIZE}) — signed, arm64, EOS and the dictionary aboard"
echo "    Upload it in Play Console: Test and release → your track → Create new release."
