#!/usr/bin/env bash
# Record one take of self-playing gameplay for cutting social ads from.
#
#     tools/adreel.sh --seed 7 --seconds 16 --out build/ads/raw/take-7
#
# A thin wrapper over tools/record.sh, which owns everything awkward about
# recording a Godot scene — the project.godot viewport edit and its restore, the
# lock that stops two recorders fighting over it, and the transcode. This file
# exists so the ad workflow keeps a name that says what it is for; the trailer
# calls the same recorder with a different scene.
set -euo pipefail
cd "$(dirname "$0")/.."
exec tools/record.sh --script tools/adreel.gd --out build/ads/raw/take "$@"
