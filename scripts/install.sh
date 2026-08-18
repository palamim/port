#!/bin/bash
# Installs Port as a per-user LaunchAgent: starts it now, and arms it to
# start at every future login. Safe to re-run (e.g. after a rebuild) --
# it just rebuilds, repackages, and reloads it.
#
# Packages the binary into a minimal .app bundle rather than running the
# raw executable directly, purely so the LaunchAgent launches something
# with a stable bundle identifier and Info.plist (matching
# scripts/package.sh's bundle) instead of a bare binary path. Plain
# ad-hoc signing (`codesign --sign -`) is enough here -- unlike
# Starboard (this script's model), Port requests no permission that
# needs a stable TCC identity across rebuilds, so there's no certificate
# dance to do. See CLAUDE.md's "No Accessibility permission" section for
# why.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LABEL="com.port.app"
BUILD_DIR="$REPO_DIR/.build/release"
BIN_PATH="$BUILD_DIR/Port"
APP_PATH="$BUILD_DIR/Port.app"
APP_BIN_PATH="$APP_PATH/Contents/MacOS/Port"
PLIST_PATH="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG_PATH="$HOME/Library/Logs/Port.log"

source "$REPO_DIR/scripts/_bundle.sh"

echo "Building release binary..."
(cd "$REPO_DIR" && swift build -c release)

echo "Packaging $APP_PATH..."
rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"
cp "$BIN_PATH" "$APP_BIN_PATH"

write_port_bundle "$APP_PATH" "$LABEL" "$REPO_DIR"

codesign --force --deep --sign - --identifier "$LABEL" "$APP_PATH"

mkdir -p "$HOME/Library/LaunchAgents"

cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$APP_BIN_PATH</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$LOG_PATH</string>
    <key>StandardErrorPath</key>
    <string>$LOG_PATH</string>
</dict>
</plist>
EOF

launchctl unload "$PLIST_PATH" 2>/dev/null || true
launchctl load "$PLIST_PATH"

echo "Installed and started."
echo
echo "Turn off (stops it now, and skips it at future logins):"
echo "  launchctl unload $PLIST_PATH"
echo
echo "Turn back on:"
echo "  launchctl load $PLIST_PATH"
echo
echo "Uninstall entirely: scripts/uninstall.sh"
