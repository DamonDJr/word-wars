#!/usr/bin/env bash
# tools/ship-ios.sh, pinned to the crossplay branch. Temporary: delete it once
# crossplay is merged into main, and go back to ship-ios.sh.
#
# The original builds whatever branch this checkout is on and reads the version
# from the files on disk. This one always builds origin/crossplay and reads the
# version from there too, so it ships the same thing whichever branch you have
# checked out — including main, where the original would ship main.
#
#   tools/ship-ios-crossplay.sh
#   tools/ship-ios-crossplay.sh --dry-run     everything up to the dispatch, then stop
#
# The commands that used to be typed by hand — dispatch the workflow, watch it,
# download the IPA, upload it — with the races between them closed. Needs `gh`
# (authenticated) and `asc` on PATH.
#
# Override with the environment if you need to:
#   ASC_APP_ID=6802900966   the App Store Connect app
#   REPO=owner/name         defaults to whatever `origin` points at
#   ARTIFACT=...            the workflow's upload-artifact name
#   IPA=WordWars.ipa        where the download lands
set -euo pipefail

cd "$(dirname "$0")/.."

DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

WORKFLOW=ios.yml
ARTIFACT="${ARTIFACT:-WordWars-ios-app-store}"
IPA="${IPA:-WordWars.ipa}"
ASC_APP_ID="${ASC_APP_ID:-6802900966}"
REPO="${REPO:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"

for tool in gh asc python3; do
	command -v "$tool" >/dev/null || { echo "FAILED: $tool is not on PATH." >&2; exit 1; }
done

BRANCH=crossplay

# The runner builds what GitHub has on the branch, so that is what is checked
# and what the version is read from — never this checkout, which may be on
# another branch entirely.
echo "==> Fetching origin/$BRANCH"
git fetch --quiet origin "$BRANCH"
TARGET=$(git rev-parse "origin/$BRANCH")
VERSION=$(git show "origin/$BRANCH:project.godot" \
	| sed -n 's/^config\/version="\(.*\)"$/\1/p')

# The one way this checkout can still mislead: being on crossplay with commits
# that were never pushed. Those are not in the build, so say so before an upload.
if [ "$(git rev-parse --abbrev-ref HEAD)" = "$BRANCH" ] \
		&& [ "$(git rev-parse HEAD)" != "$TARGET" ]; then
	echo "FAILED: your crossplay and origin/crossplay disagree, so the runner would" >&2
	echo "        build something other than what you are looking at. Push first." >&2
	exit 1
fi

echo "==> Building $VERSION from $(git rev-parse --short "$TARGET") ($BRANCH) on $REPO"

# The race this script exists to close.
#
# `gh workflow run` returns as soon as the dispatch is accepted, several seconds
# before the run it asked for exists. `gh run watch` with no id attaches to the
# newest run — which in that window is the PREVIOUS one, already finished. It
# would return instantly and successfully, the download would fetch the previous
# build's artifact, and that is what would go to Apple: a stale binary, uploaded
# under a fresh build number, with every command having exited zero. So the id
# before dispatch is remembered and the new run is waited for by name.
BEFORE=$(gh run list --workflow "$WORKFLOW" -R "$REPO" --branch "$BRANCH" --limit 1 \
	--json databaseId --jq '.[0].databaseId // empty')

if [ "$DRY_RUN" = 1 ]; then
	echo "    would dispatch $WORKFLOW on $BRANCH"
	echo "    newest run right now is ${BEFORE:-none}; would wait for a different one"
	echo "    would upload $IPA to app $ASC_APP_ID"
	echo "==> Dry run, nothing dispatched"
	exit 0
fi

gh workflow run "$WORKFLOW" -R "$REPO" --ref "$BRANCH"

echo "==> Waiting for the run to appear"
RUN=""
for _ in $(seq 60); do
	sleep 2
	RUN=$(gh run list --workflow "$WORKFLOW" -R "$REPO" --branch "$BRANCH" --limit 1 \
		--json databaseId --jq '.[0].databaseId // empty')
	[ -n "$RUN" ] && [ "$RUN" != "$BEFORE" ] && break
	RUN=""
done
if [ -z "$RUN" ]; then
	echo "FAILED: no new run showed up within two minutes." >&2
	echo "        Check https://github.com/$REPO/actions" >&2
	exit 1
fi
echo "    https://github.com/$REPO/actions/runs/$RUN"

# --exit-status, or a red build walks straight on to the download and the upload.
gh run watch "$RUN" -R "$REPO" --exit-status

echo "==> Downloading $ARTIFACT"
rm -f "$IPA"
gh run download "$RUN" -R "$REPO" -n "$ARTIFACT" -D .
[ -f "$IPA" ] || { echo "FAILED: $IPA is not in the artifact." >&2; exit 1; }

# Belt and braces on the same worry as the run id: read the version back out of
# the thing actually about to be uploaded, rather than out of the file that was
# meant to have produced it.
read -r GOT_VERSION GOT_BUILD < <(python3 - "$IPA" <<'PY'
import plistlib, sys, zipfile

z = zipfile.ZipFile(sys.argv[1])
name = next(n for n in z.namelist()
            if n.count("/") == 2 and n.endswith(".app/Info.plist"))
p = plistlib.loads(z.read(name))
print(p["CFBundleShortVersionString"], p["CFBundleVersion"])
PY
)
if [ "$GOT_VERSION" != "$VERSION" ]; then
	echo "FAILED: project.godot says $VERSION, the IPA says $GOT_VERSION." >&2
	echo "        Something is out of step; not uploading." >&2
	exit 1
fi

echo "==> Uploading $GOT_VERSION build $GOT_BUILD to app $ASC_APP_ID"
asc builds upload --app "$ASC_APP_ID" --ipa "$IPA" --wait

echo "==> $GOT_VERSION build $GOT_BUILD is in App Store Connect"
