#!/bin/bash
# Builds the exact artifact scripts/package.sh produces for a GitHub
# Release, then swaps it into /Applications in place of whatever Port is
# running there. A fast way to try a change as if it had already
# shipped, without going through GitHub or scripts/install.sh's separate
# LaunchAgent identity -- daily use only needs one Port, and this keeps
# it that way instead of running two copies side by side.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="$REPO_DIR/.build/release-dist/Port.app"
INSTALLED_PATH="/Applications/Port.app"

echo "Quitting any running Port..."
pkill -x Port 2>/dev/null || true
sleep 1

"$REPO_DIR/scripts/package.sh"

echo "Replacing $INSTALLED_PATH..."
rm -rf "$INSTALLED_PATH"
cp -R "$APP_PATH" "$INSTALLED_PATH"

echo "Opening $INSTALLED_PATH..."
open "$INSTALLED_PATH"

echo
echo "Done."
