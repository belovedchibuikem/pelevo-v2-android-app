#!/usr/bin/env bash
# Archive Pelevo 5.2.0 for App Store Connect. Run on macOS with Xcode 16+.
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "iOS archives must be built on a Mac with Xcode." >&2
  exit 1
fi

if [[ ! -f ios/Flutter/AdMob.xcconfig ]]; then
  echo "Copy ios/Flutter/AdMob.xcconfig.example to ios/Flutter/AdMob.xcconfig and set the production iOS AdMob app id." >&2
  exit 1
fi

if [[ ! -f ios/dart_defines.release.json ]]; then
  echo "Copy ios/dart_defines.release.json.example to ios/dart_defines.release.json and fill production values." >&2
  exit 1
fi

flutter pub get
cd ios
pod install --repo-update
cd ..

flutter build ipa --release \
  --obfuscate \
  --split-debug-info=build/app/outputs/symbols \
  --export-options-plist=ios/ExportOptions.plist \
  --dart-define-from-file=ios/dart_defines.release.json

echo
echo "IPA: build/ios/ipa/pelevo.ipa"
echo "Upload with: xcrun altool --upload-app or Xcode Organizer, or Transporter."
