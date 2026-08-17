#!/usr/bin/env bash
# Fetch the EOS native binaries that `.gitignore` deliberately keeps out of git.
#
# The GDScript half of addons/epic-online-services-godot/ is committed; this
# restores bin/ — roughly 240 MB of prebuilt GDExtension libraries plus Epic's
# own SDK. Run it after a fresh clone, and in CI before any export.
#
# Pinned to one upstream build on purpose: the release hash is part of the URL,
# so this fetches byte-identical files every time rather than whatever "latest"
# happens to mean on the day.
set -euo pipefail

VERSION="2.3.0"
HASH="e84320567a3a17d305478f5796707e69d2bdac4f"
BASE="https://github.com/3ddelano/epic-online-services-godot/releases/download/${VERSION}"

# Platforms we actually ship. Android is skipped because it is not a target.
# iOS is here now that the export path is proven: without it the phone build
# links no EOS library at all, and the GDExtension fails at load with every EOS
# script failing to parse behind it.
PLATFORMS=(linux windows macos ios)

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ADDON="${ROOT}/addons/epic-online-services-godot"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

if ! command -v unzip >/dev/null; then
  echo "error: unzip is required" >&2
  exit 1
fi

echo "Fetching EOSG ${VERSION} binaries for: ${PLATFORMS[*]}"
mkdir -p "${ADDON}/bin"

for p in "${PLATFORMS[@]}"; do
  archive="epic-online-services-godot-${p}-${HASH}.zip"
  echo "  ${p}…"
  curl -fsSL --retry 3 -o "${TMP}/${p}.zip" "${BASE}/${archive}"
  unzip -q -o "${TMP}/${p}.zip" -d "${TMP}/x-${p}"

  src="${TMP}/x-${p}/epic-online-services-godot/addons/epic-online-services-godot"
  # Each per-platform archive carries the whole addon; we only want its bin/,
  # since the GDScript is already in the repo.
  cp -r "${src}/bin/${p}" "${ADDON}/bin/"
done

echo "Done. ${ADDON}/bin now has: $(ls "${ADDON}/bin" | tr '\n' ' ')"
