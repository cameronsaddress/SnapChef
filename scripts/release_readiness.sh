#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-ios/DerivedData}"
IOS_DESTINATION="${IOS_DESTINATION:-platform=iOS Simulator,name=iPhone 16,OS=18.5}"
PROJECT_PATH="ios/SnapChef.xcodeproj"
SCHEME="SnapChef"

run_step() {
  local label="$1"
  shift
  echo "\n==> ${label}"
  "$@"
}

run_step "Debug build" xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination "$IOS_DESTINATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  build CODE_SIGNING_ALLOWED=NO

run_step "Release build" xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "$IOS_DESTINATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  build CODE_SIGNING_ALLOWED=NO

run_step "Debug tests" xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination "$IOS_DESTINATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  test CODE_SIGNING_ALLOWED=NO

echo "\n==> Guardrail checks"

# Internal test-capture UI must not ship.
if grep -R -n "Run Test Capture\\|Test Capture" ios/SnapChef/Features/Camera >/dev/null 2>&1; then
  echo "❌ Internal test-capture UI strings detected under Features/Camera"
  exit 1
fi

RELEASE_FLAGS=$(xcodebuild -project "$PROJECT_PATH" -scheme "$SCHEME" -configuration Release -showBuildSettings | grep "SWIFT_ACTIVE_COMPILATION_CONDITIONS" || true)
if echo "$RELEASE_FLAGS" | grep -q "DEBUG"; then
  echo "❌ Release build settings still include DEBUG compilation condition"
  echo "$RELEASE_FLAGS"
  exit 1
fi

RELEASE_APP="$DERIVED_DATA_PATH/Build/Products/Release-iphonesimulator/SnapChef.app"
if [[ -f "$RELEASE_APP/Info.plist" ]]; then
  API_KEY_VALUE=$(/usr/libexec/PlistBuddy -c "Print :SNAPCHEF_API_KEY" "$RELEASE_APP/Info.plist" 2>/dev/null || true)
  if [[ -z "$API_KEY_VALUE" || "$API_KEY_VALUE" == *'$('* ]]; then
    echo "⚠️ SNAPCHEF_API_KEY unresolved in Release Info.plist (expected for local unsigned builds)."
  fi

  # Privacy manifest: required for "required reason" API declarations and increasingly expected by App Store tooling.
  if [[ ! -f "$RELEASE_APP/PrivacyInfo.xcprivacy" ]]; then
    echo "❌ PrivacyInfo.xcprivacy missing from Release app bundle"
    exit 1
  fi

  # TikTok client secret should not be shipped in the app binary. Prefer server-side exchange/PKCE.
  TIKTOK_SECRET_VALUE=$(/usr/libexec/PlistBuddy -c "Print :TikTokClientSecret" "$RELEASE_APP/Info.plist" 2>/dev/null || true)
  if [[ -n "$TIKTOK_SECRET_VALUE" && "$TIKTOK_SECRET_VALUE" != *'$('* ]]; then
    echo "⚠️ TikTokClientSecret is resolved in Release Info.plist. Shipping OAuth client secrets in an app is insecure."
  fi
fi

echo "\n✅ Release readiness checks passed"
