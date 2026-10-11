#!/usr/bin/env bash
# Builds ios/plugins/HingeBridge.{debug,release}.xcframework from
# ios/plugins-src/HingeBridge/HingeBridge.mm. macOS only: it needs the iPhone SDK.
#
#     tools/build-hingebridge.sh
#
# Run by .github/workflows/ios.yml before the export. The binaries are not
# committed — they are ten kilobytes of output of a file that is, and a binary in
# the tree is one nobody can review.
#
# Only the UIKit that every SDK has is used, and the class that matters is looked
# up by name at run time, so this compiles on a runner whose Xcode predates the
# iPhone Duo. See the note at the top of the source.
set -euo pipefail
cd "$(dirname "$0")/.."

SRC=ios/plugins-src/HingeBridge/HingeBridge.mm
OUT=ios/plugins
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

SDK="$(xcrun --sdk iphoneos --show-sdk-path)"

xcrun --sdk iphoneos clang \
	-arch arm64 -miphoneos-version-min=15.0 -isysroot "$SDK" \
	-fobjc-arc -fmodules -O2 -Wall \
	-c "$SRC" -o "$WORK/HingeBridge.o"
libtool -static -o "$WORK/HingeBridge.a" "$WORK/HingeBridge.o"

# The engine's generated plugin code is C++ and asks for these two by their
# C++-mangled names. A library that exports them under any other name compiles,
# builds, and then fails the *archive*, twenty minutes into the signed build — so
# the names are checked here, where a failure only turns the bridge off.
for sym in __Z17hinge_bridge_initv __Z19hinge_bridge_deinitv; do
	if ! nm -g "$WORK/HingeBridge.a" 2>/dev/null | grep -q " T $sym\$"; then
		echo "HingeBridge.a does not export $sym (C++ linkage); the engine would not link it." >&2
		nm -g "$WORK/HingeBridge.a" >&2 || true
		exit 1
	fi
done

for cfg in debug release; do
	rm -rf "$OUT/HingeBridge.$cfg.xcframework"
	xcodebuild -create-xcframework -library "$WORK/HingeBridge.a" \
		-output "$OUT/HingeBridge.$cfg.xcframework"
done
echo "built $OUT/HingeBridge.{debug,release}.xcframework"
