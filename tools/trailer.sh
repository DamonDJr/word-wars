#!/usr/bin/env bash
# Record the scripted trailer take — the whole arc, in one pass.
#
#     tools/trailer.sh --seed 11 --out build/trailer/raw/take
#
# A thin wrapper over tools/record.sh, same as tools/adreel.sh. The scene list
# and its timings live in tools/trailer.gd; the length of the take is whatever
# that script adds up to, so there is deliberately no --seconds here.
set -euo pipefail
cd "$(dirname "$0")/.."
exec tools/record.sh --script tools/trailer.gd --out build/trailer/raw/take "$@"
