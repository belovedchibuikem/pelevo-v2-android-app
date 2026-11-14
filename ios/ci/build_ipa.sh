#!/usr/bin/env bash
# Codemagic + local Mac IPA. Secrets come from the environment, never git.
set -euo pipefail
cd "${CM_BUILD_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"

: "${ADMOB_IOS_APP_ID:?Set ADMOB_IOS_APP_ID in Codemagic group pelevo_ios.}"
if [[ ! "$ADMOB_IOS_APP_ID" =~ ^ca-app-pub-[0-9]+~[0-9]+$ ]]; then
  echo "ADMOB_IOS_APP_ID must look like ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY" >&2
  exit 1
fi

printf 'ADMOB_IOS_APP_ID=%s\n' "$ADMOB_IOS_APP_ID" > ios/Flutter/AdMob.xcconfig

flutter --version
flutter precache --ios
flutter pub get

(cd ios && pod install --repo-update)

if [[ -z "${CM_BUILD_DIR:-}" ]]; then
  echo "This script is for Codemagic. On a Mac use ios/build_appstore.sh." >&2
  exit 1
fi

keychain initialize
app-store-connect fetch-signing-files "${BUNDLE_ID:-com.Podemeraldltd.pelevo}" \
  --type IOS_APP_STORE \
  --create
keychain add-certificates
xcode-project use-profiles --archive-method=app-store

bundle_id="${BUNDLE_ID:-com.Podemeraldltd.pelevo}"
app_id="${APP_STORE_APPLE_ID:-$bundle_id}"
build_number="${BUILD_NUMBER:-36}"
if command -v app-store-connect >/dev/null 2>&1; then
  tf="$(app-store-connect get-latest-testflight-build-number "$app_id" 2>/dev/null || true)"
  store="$(app-store-connect get-latest-app-store-build-number "$app_id" 2>/dev/null || true)"
  latest=0
  [[ "$tf" =~ ^[0-9]+$ ]] && latest=$tf
  if [[ "$store" =~ ^[0-9]+$ ]] && (( store > latest )); then
    latest=$store
  fi
  if (( latest >= build_number )); then
    build_number=$((latest + 1))
  fi
fi
if (( build_number < 36 )); then
  build_number=36
fi
echo "Using CFBundleVersion $build_number (marketing 5.2.0)"

export_plist="${HOME}/export_options.plist"
if [[ ! -f "$export_plist" ]]; then
  echo "Missing $export_plist after fetch-signing-files. Confirm the Pelevo App Store Connect integration and that App ID com.Podemeraldltd.pelevo exists." >&2
  exit 1
fi

flutter build ipa --release \
  --build-name=5.2.0 \
  --build-number="$build_number" \
  --obfuscate \
  --split-debug-info=build/app/outputs/symbols \
  --export-options-plist="$export_plist" \
  --dart-define="PELEVO_API_BASE_URL=${PELEVO_API_BASE_URL:-https://pelevo.com/api/v1}" \
  --dart-define="PELEVO_SENTRY_DSN=${PELEVO_SENTRY_DSN:-}" \
  --dart-define="ADMOB_REELS_IOS_AD_UNIT_ID=${ADMOB_REELS_IOS_AD_UNIT_ID:-}" \
  --dart-define="ADMOB_HOME_IOS_AD_UNIT_ID=${ADMOB_HOME_IOS_AD_UNIT_ID:-}" \
  --dart-define="ADMOB_SEARCH_IOS_AD_UNIT_ID=${ADMOB_SEARCH_IOS_AD_UNIT_ID:-}"

ls -la build/ios/ipa
