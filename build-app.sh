#!/bin/bash
# Builds ProjectHub.app — a standalone macOS menu bar app bundle.
# Usage: bash build-app.sh [release]
set -e

cd "$(dirname "$0")"

MODE="${1:-debug}"
[ "$MODE" = "release" ] && SWIFT_FLAGS="-c release" || SWIFT_FLAGS=""

VERSION="0.2.0"

echo "→ Building Swift package ($MODE)…"
swift build $SWIFT_FLAGS

if [ "$MODE" = "release" ]; then
    BIN=".build/release/ProjectHub"
else
    BIN=".build/debug/ProjectHub"
fi

APP="ProjectHub.app"
echo "→ Assembling $APP…"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

cp "$BIN" "$APP/Contents/MacOS/ProjectHub"

cat > "$APP/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.projecthub.ProjectHubBar</string>
    <key>CFBundleName</key>
    <string>ProjectHub</string>
    <key>CFBundleDisplayName</key>
    <string>Project Hub</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleExecutable</key>
    <string>ProjectHub</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHumanReadableCopyright</key>
    <string>MIT</string>
</dict>
</plist>
PLIST

# Ad-hoc code sign so macOS will run it
codesign --force --sign - "$APP/Contents/MacOS/ProjectHub"

echo ""
echo "✓ Built: $(pwd)/$APP  (v${VERSION})"
echo ""
echo "To run now:  open $APP"
echo "To install:  cp -r $APP /Applications/"
