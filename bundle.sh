#!/bin/sh
# Builds build/Squint.app: menu bar only (no Dock icon), ad-hoc signed.
# Extra arguments go to `swift build` (Homebrew passes --disable-sandbox).
set -eu
cd "$(dirname "$0")"
swift build -c release "$@"
app=build/Squint.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp .build/release/Squint "$app/Contents/MacOS/Squint"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>Squint</string>
    <key>CFBundleIdentifier</key><string>io.github.dhruv-sharma29.squint</string>
    <key>CFBundleName</key><string>Squint</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleURLName</key><string>Squint</string>
            <key>CFBundleURLSchemes</key><array><string>squint</string></array>
        </dict>
    </array>
</dict>
</plist>
PLIST
codesign --force --sign - "$app"
echo "$app"
