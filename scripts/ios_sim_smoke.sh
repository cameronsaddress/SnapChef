#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-ios/DerivedData}"
IOS_DESTINATION="${IOS_DESTINATION:-platform=iOS Simulator,name=iPhone 16,OS=18.5}"
SIM_UDID="${SIM_UDID:-645BEE5E-94C7-4842-8F1E-23CB46112B62}"
BUNDLE_ID="${BUNDLE_ID:-com.snapchefapp.app}"
OUT_DIR="${OUT_DIR:-/tmp/snapchef_smoke}"

echo "==> Boot simulator (${SIM_UDID})"
xcrun simctl boot "$SIM_UDID" >/dev/null 2>&1 || true
open -a Simulator >/dev/null 2>&1 || true
sleep 2

echo "==> Build (Debug)"
xcodebuild \
  -project ios/SnapChef.xcodeproj \
  -scheme SnapChef \
  -configuration Debug \
  -destination "$IOS_DESTINATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  build >/dev/null 2>&1

APP_PATH="$DERIVED_DATA_PATH/Build/Products/Debug-iphonesimulator/SnapChef.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "❌ App not found at $APP_PATH"
  exit 1
fi

echo "==> Install"
xcrun simctl install "$SIM_UDID" "$APP_PATH" >/dev/null 2>&1

# Skip onboarding for deterministic screenshots (ContentView gates on hasLaunchedBefore).
xcrun simctl spawn "$SIM_UDID" defaults write "$BUNDLE_ID" hasLaunchedBefore -bool YES >/dev/null 2>&1 || true

mkdir -p "$OUT_DIR"

shot() {
  local label="$1"
  shift
  echo "==> Launch + screenshot: ${label}"
  xcrun simctl terminate "$SIM_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl launch "$SIM_UDID" "$BUNDLE_ID" "$@" >/dev/null 2>&1 || true
  # Give the launch animation + initial view transitions time to complete before capturing.
  # (ContentView shows LaunchAnimationView for ~3s; there is also a brief fade gap).
  sleep 8
  xcrun simctl io "$SIM_UDID" screenshot "$OUT_DIR/${label}.png" >/dev/null 2>&1
}

shot "home" -startTab home
shot "feed" -startTab feed
shot "discover_chefs" -startTab feed -presentDiscoverChefs
shot "recipes" -startTab recipes
shot "profile" -startTab profile
shot "camera" -startTab camera
shot "detective" -startTab detective

echo "✅ Screenshots written to: $OUT_DIR"
