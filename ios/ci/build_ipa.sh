#!/usr/bin/env bash
# Codemagic iOS compile. Secrets come from the environment, never git.
# Signed IPA + TestFlight needs APP_STORE_CONNECT_* and CERTIFICATE_PRIVATE_KEY.
# Without those, this still compiles an unsigned .app for CI artifacts (not installable on a phone).
set -euo pipefail
cd "${CM_BUILD_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"

can_sign=false
if [[ -n "${APP_STORE_CONNECT_PRIVATE_KEY:-}" && \
      -n "${APP_STORE_CONNECT_KEY_IDENTIFIER:-}" && \
      -n "${APP_STORE_CONNECT_ISSUER_ID:-}" && \
      -n "${CERTIFICATE_PRIVATE_KEY:-}" ]]; then
  can_sign=true
fi

# Google sample iOS app id — compile-only. Never used when signing for TestFlight/App Store.
sample_admob='ca-app-pub-3940256099942544~1458002511'
if [[ -z "${ADMOB_IOS_APP_ID:-}" ]]; then
  if [[ "$can_sign" == true ]]; then
    echo "Set ADMOB_IOS_APP_ID in Codemagic group pelevo_ios (ca-app-pub-…~…)." >&2
    exit 1
  fi
  ADMOB_IOS_APP_ID="$sample_admob"
  echo "ADMOB_IOS_APP_ID unset; using Google sample id for unsigned compile only."
elif [[ ! "$ADMOB_IOS_APP_ID" =~ ^ca-app-pub-[0-9]+~[0-9]+$ ]]; then
  echo "ADMOB_IOS_APP_ID must look like ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY" >&2
  exit 1
fi
export ADMOB_IOS_APP_ID
printf 'ADMOB_IOS_APP_ID=%s\n' "$ADMOB_IOS_APP_ID" > ios/Flutter/AdMob.xcconfig

flutter --version
# sentry_flutter 10 is SPM-only; google_mobile_ads 8+ supports SPM.
flutter config --enable-swift-package-manager
flutter precache --ios
flutter pub get

(cd ios && pod install --repo-update)

if [[ -z "${CM_BUILD_DIR:-}" ]]; then
  echo "This script is for Codemagic. On a Mac use ios/build_appstore.sh." >&2
  exit 1
fi

bundle_id="${BUNDLE_ID:-com.podemeraldsltd.pelevo}"
app_id="${APP_STORE_APPLE_ID:-$bundle_id}"
build_number="${BUILD_NUMBER:-36}"

dart_defines=(
  --dart-define="PELEVO_API_BASE_URL=${PELEVO_API_BASE_URL:-https://pelevo.com/api/v1}"
  --dart-define="PELEVO_SENTRY_DSN=${PELEVO_SENTRY_DSN:-}"
  --dart-define="ADMOB_REELS_IOS_AD_UNIT_ID=${ADMOB_REELS_IOS_AD_UNIT_ID:-}"
  --dart-define="ADMOB_HOME_IOS_AD_UNIT_ID=${ADMOB_HOME_IOS_AD_UNIT_ID:-}"
  --dart-define="ADMOB_SEARCH_IOS_AD_UNIT_ID=${ADMOB_SEARCH_IOS_AD_UNIT_ID:-}"
)

# Flutter SPM integration rewrites the Xcode project to iOS 15. GoogleCast needs 16.
pin_ios_16() {
  python3 - <<'PY'
from pathlib import Path
import re
root = Path("ios")
pbx = re.compile(r"IPHONEOS_DEPLOYMENT_TARGET = 1[0-5]\.\d+;")
for path in root.rglob("project.pbxproj"):
    text = path.read_text(encoding="utf-8")
    updated = pbx.sub("IPHONEOS_DEPLOYMENT_TARGET = 16.0;", text)
    if updated != text:
        path.write_text(updated, encoding="utf-8")
        print(f"Pinned {path} to iOS 16.0")
podfile = root / "Podfile"
if podfile.exists():
    t = podfile.read_text(encoding="utf-8")
    u = re.sub(r"platform :ios, '1[0-5]\.\d+'", "platform :ios, '16.0'", t)
    u = u.replace("IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'", "IPHONEOS_DEPLOYMENT_TARGET'] = '16.0'")
    if u != t:
        podfile.write_text(u, encoding="utf-8")
info = root / "Flutter" / "AppFrameworkInfo.plist"
if info.exists():
    t = info.read_text(encoding="utf-8")
    u = t.replace("<string>15.0</string>", "<string>16.0</string>")
    if u != t:
        info.write_text(u, encoding="utf-8")
PY
}

if [[ "$can_sign" != true ]]; then
  echo "App Store Connect keys not set. Compiling unsigned iOS release (no IPA, no TestFlight, no App Store)."
  flutter build ios --config-only --release --no-codesign \
    --build-name=5.2.0 \
    --build-number="$build_number" \
    "${dart_defines[@]}"
  pin_ios_16
  mkdir -p build/ios/iphoneos
  # Command-line IPHONEOS_DEPLOYMENT_TARGET beats Flutter SPM rewriting the pbxproj to 15.0.
  xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner \
    -configuration Release -sdk iphoneos \
    -destination 'generic/platform=iOS' \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
    IPHONEOS_DEPLOYMENT_TARGET=16.0 \
    FLUTTER_BUILD_NAME=5.2.0 \
    FLUTTER_BUILD_NUMBER="$build_number" \
    CONFIGURATION_BUILD_DIR="$PWD/build/ios/iphoneos"
  mkdir -p build/ios/ipa
  app_path="build/ios/iphoneos/Runner.app"
  if [[ ! -d "$app_path" ]]; then
    echo "Expected $app_path after flutter build ios --no-codesign." >&2
    find build/ios -maxdepth 4 -name 'Runner.app' -print || true
    exit 1
  fi
  ditto -c -k --keepParent "$app_path" build/ios/ipa/Pelevo-unsigned.app.zip
  ls -la build/ios/ipa
  echo "Download Pelevo-unsigned.app.zip from Artifacts. It will not install on an iPhone until you add signing keys and rebuild."
  exit 0
fi

keychain initialize
app-store-connect fetch-signing-files "$bundle_id" \
  --type IOS_APP_STORE \
  --create \
  --certificate-key=@env:CERTIFICATE_PRIVATE_KEY
keychain add-certificates
xcode-project use-profiles --archive-method=app-store

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
  echo "Missing $export_plist after fetch-signing-files. Confirm APP_STORE_CONNECT_* vars in pelevo_ios and that App ID com.podemeraldsltd.pelevo exists." >&2
  exit 1
fi

flutter build ios --config-only --release \
  --build-name=5.2.0 \
  --build-number="$build_number" \
  "${dart_defines[@]}"
pin_ios_16
flutter build ipa --release \
  --build-name=5.2.0 \
  --build-number="$build_number" \
  --obfuscate \
  --split-debug-info=build/app/outputs/symbols \
  --export-options-plist="$export_plist" \
  "${dart_defines[@]}"

ls -la build/ios/ipa
