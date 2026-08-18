# Shared by package.sh and install.sh: writes Contents/Resources/AppIcon.icns
# (if present) and Contents/Info.plist for a Port.app bundle. Not a
# standalone script -- sourced, not executed, so both build paths produce
# byte-identical bundle metadata instead of drifting apart the way two
# copy-pasted heredocs did before.

# write_port_bundle <app_path> <label> <repo_dir>
write_port_bundle() {
    local app_path="$1" label="$2" repo_dir="$3"
    local icon_path="$repo_dir/assets/AppIcon.icns"

    # No app icon yet -- CFBundleIconFile is omitted when this is absent,
    # so the .app just gets the generic executable icon instead of
    # failing to package.
    local icon_key=""
    if [ -f "$icon_path" ]; then
        cp "$icon_path" "$app_path/Contents/Resources/AppIcon.icns"
        icon_key="    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
"
    fi

    cat > "$app_path/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>$label</string>
    <key>CFBundleName</key>
    <string>Port</string>
    <key>CFBundleExecutable</key>
    <string>Port</string>
${icon_key}    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$(cat "$repo_dir/VERSION")</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHumanReadableCopyright</key>
    <string>MIT License</string>
</dict>
</plist>
EOF
}
