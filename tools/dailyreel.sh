#!/usr/bin/env bash
# Record a whole daily run at a person's pace, for posting.
#
#     tools/dailyreel.sh                        # today's board
#     tools/dailyreel.sh --date 2026-09-27      # the board for the day you post
#
# Lands in build/daily/daily-<date>.mp4, 1080x1920 with game audio. A thin
# wrapper over tools/record.sh; see tools/dailyreel.gd for what it plays.
set -euo pipefail
cd "$(dirname "$0")/.."
DATE=$(date +%F)
for ((i = 1; i <= $#; i++)); do
	[[ "${!i}" == "--date" ]] && { j=$((i + 1)); DATE="${!j}"; }
done
exec tools/record.sh --script tools/dailyreel.gd --out "build/daily/daily-$DATE" "$@"
