#!/bin/bash
# Build ColorSense, install it on a booted simulator, launch it, and save a screenshot.
# Usage: Scripts/run-sim.sh [screenshot-path]
#
# Boots "iPhone 17" if no simulator is already running. Derived data goes to .build/
# (gitignored) so it doesn't collide with Xcode's own DerivedData.
set -euo pipefail

cd "$(dirname "$0")/.."

DERIVED=".build/DerivedData"
APP="$DERIVED/Build/Products/Debug-iphonesimulator/ColorSense.app"
SHOT="${1:-.build/sim-screenshot.png}"

DEVICE=$(xcrun simctl list devices booted -j | python3 -c \
  'import json,sys; d=[x for v in json.load(sys.stdin)["devices"].values() for x in v]; print(d[0]["udid"] if d else "")')

if [ -z "$DEVICE" ]; then
  echo "No booted simulator; booting iPhone 17..."
  xcrun simctl boot "iPhone 17"
  open -a Simulator
  DEVICE=$(xcrun simctl list devices booted -j | python3 -c \
    'import json,sys; d=[x for v in json.load(sys.stdin)["devices"].values() for x in v]; print(d[0]["udid"])')
fi

xcodebuild -project ColorSense.xcodeproj -scheme ColorSense \
  -destination "id=$DEVICE" -derivedDataPath "$DERIVED" build | tail -3

BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$APP/Info.plist")

xcrun simctl install "$DEVICE" "$APP"
xcrun simctl terminate "$DEVICE" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl launch "$DEVICE" "$BUNDLE_ID"

# First paint lags launch by several seconds: Clerk fires its (failing) placeholder-key requests
# during startup. Screenshotting sooner reliably captures a blank white frame.
sleep 7
xcrun simctl io "$DEVICE" screenshot "$SHOT"
echo "Screenshot: $SHOT"
