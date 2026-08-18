#!/bin/bash
# Builds a release .app bundle and zips it for distribution (GitHub
# Releases, or a by-hand download). Used both by hand and by
# .github/workflows/release.yml on a version-tag push.
#
# Unlike scripts/install.sh, this does NOT touch LaunchAgents, the login
# keychain, or a local signing certificate -- it ad-hoc signs
# (`codesign --sign -`) instead. install.sh's cert-based signing exists
# specifically so a launchd-launched process keeps a stable TCC identity
# for Accessibility across rebuilds; a downloaded .app is launched
# interactively (Finder/`open`), which doesn't have that requirement, so
# plain ad-hoc signing -- enough to satisfy Gatekeeper's "is this signed
# at all" check and let the binary run once approved -- is sufficient
# here. No entitlements file is applied, matching install.sh: Port is
# unsandboxed and needs no entitlements either way.
#
# Builds into its own .build/release-dist/, deliberately NOT
# install.sh's .build/release/ -- that path is also where the
# LaunchAgent's ProgramArguments points. The two used to collide for
# Starboard (this script's model): running package.sh after install.sh
# clobbered the cert-signed .build/release/*.app with an ad-hoc-signed
# one, silently breaking Accessibility trust for the already-installed,
# launchd-run instance. Separate output directories make that collision
# structurally impossible instead of relying on remembering not to run
# the two scripts against the same tree.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LABEL="com.port.app"
ARM64_SCRATCH="$REPO_DIR/.build-arm64"
X86_64_SCRATCH="$REPO_DIR/.build-x86_64"
APP_PATH="$REPO_DIR/.build/release-dist/Port.app"
APP_BIN_PATH="$APP_PATH/Contents/MacOS/Port"
ZIP_PATH="$REPO_DIR/Port.zip"

source "$REPO_DIR/scripts/_bundle.sh"

# Two single-arch builds + lipo, not `swift build --arch arm64 --arch
# x86_64` in one invocation: that form hands the universal-binary step to
# xcbuild, which needs a full Xcode install and isn't available with just
# Command Line Tools. Each --arch build also needs its own --scratch-path:
# sharing one .build/ across arches corrupts SwiftPM's build database.
# Isolated scratch dirs sidestep that entirely, and also mean the two
# builds have no shared state to race on, so they run concurrently rather
# than one after the other.
echo "Building release binaries (arm64 + x86_64)..."
(cd "$REPO_DIR" && swift build -c release --arch arm64 --scratch-path "$ARM64_SCRATCH") &
arm64_pid=$!
(cd "$REPO_DIR" && swift build -c release --arch x86_64 --scratch-path "$X86_64_SCRATCH") &
x86_64_pid=$!

wait "$arm64_pid"
wait "$x86_64_pid"

echo "Packaging $APP_PATH..."
rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"
lipo -create -output "$APP_BIN_PATH" \
    "$ARM64_SCRATCH/arm64-apple-macosx/release/Port" \
    "$X86_64_SCRATCH/x86_64-apple-macosx/release/Port"

write_port_bundle "$APP_PATH" "$LABEL" "$REPO_DIR"

echo "Ad-hoc signing $APP_PATH..."
codesign --force --deep --sign - --identifier "$LABEL" "$APP_PATH"

echo "Zipping..."
rm -f "$ZIP_PATH"
# ditto, not zip: preserves the code signature's extended attributes,
# which a plain `zip` can silently drop.
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

echo
echo "Done: $ZIP_PATH"
