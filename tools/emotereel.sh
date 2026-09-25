#!/usr/bin/env bash
# Record the end-of-match emote row demo — the whole thing, in one pass.
#
#     tools/emotereel.sh --seed 11 --out build/emotes/raw/take
#
# A thin wrapper over tools/record.sh, same as tools/trailer.sh and
# tools/adreel.sh. The scenes and their timings live in tools/emotereel.gd, and
# the length of the take is whatever those add up to, so there is deliberately
# no --seconds here.
set -euo pipefail
cd "$(dirname "$0")/.."
exec tools/record.sh --script tools/emotereel.gd --out build/emotes/raw/take "$@"
