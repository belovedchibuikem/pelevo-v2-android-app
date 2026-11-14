# Pelevo — Google Play & App Store release guide

Use this checklist before uploading. Legal copy lives at:

- Privacy Policy: https://pelevo.com/privacy
- Terms: https://pelevo.com/terms

In-app: **Settings & Account → Privacy & data**, and **About → Terms / Privacy**.

---

## 1. Accounts & console (you must do)

| Step | Google Play | Apple App Store |
|---|---|---|
| Developer account | Play Console | Apple Developer Program |
| App ID | `com.Podemeraldltd.pelevo` | `com.Podemeraldltd.pelevo` |
| Signing | Upload keystore + Play App Signing | Xcode automatic signing / distribution cert |
| Capabilities | App Links (`pelevo.com` + `assetlinks.json`) — see [app-links.md](configuration/app-links.md) | Push Notifications, Sign in with Apple, Associated Domains |
| Privacy forms | Data safety questionnaire | App Privacy nutrition labels |
| Ads | AdMob app + declare ads | AdMob + ATT / UMP |
| IAP | Plus + coin packs | Same product IDs in App Store Connect |
| Account deletion | In-app path + optional web URL | Guideline 5.1.1(v) — in-app path required |
| Age rating | Complete questionnaire (listen-to-earn / UGC) | Same; disclose unrestricted web + user content |

### Hosted legal URLs for listings

- Privacy: `https://pelevo.com/privacy`
- Terms: `https://pelevo.com/terms`
- Support: use your public support / help email or help center URL
- Account deletion (optional Play field): deep link or document that users open **Settings → Privacy & data → Delete my account**

---

## 2. Android release build

1. Copy `android/key.properties.example` → `android/key.properties` and set the upload keystore path/passwords (never commit).
2. Confirm App Links: `https://pelevo.com/.well-known/assetlinks.json` is HTTP 200 with no redirect and includes the Play App Signing SHA-256. Do not put `www.pelevo.com` in the `autoVerify` filter until www serves `assetlinks.json` without a 301 (details in [app-links.md](configuration/app-links.md)).
3. Play quality: release already uses R8 (`isMinifyEnabled` + `isShrinkResources` + `android.enableR8.fullMode=true`). Edge-to-edge uses `WindowCompat.setDecorFitsSystemWindows` (AGP 8.7–compatible) and system-bar styles that omit deprecated `statusBarColor` / `navigationBarColor`. Keep mapping.txt from `build/app/outputs/mapping/release/` for crash deobfuscation.
4. **16 KB page sizes** (Play / Android 15+): stay on AGP ≥8.5.1 (Pelevo uses 9.1.0), NDK via `flutter.ndkVersion` (28.2.x), `packaging.jniLibs.useLegacyPackaging=false`, and `android.bundle.enableUncompressedNativeLibs=true`. After building the AAB, confirm arm64 `.so` `PT_LOAD` align ≥ `0x4000` with NDK `llvm-readelf -lW`, and that Play’s pre-launch “16 KB devices” lab is clean. If Play still flags a specific `.so`, upgrade that plugin (common sources: `jni` / `sentry_flutter` / ads SDKs).
5. Store prices: use `in_app_purchase_android` ^0.5.0 (Billing Library 8+; current plugin ships 9.1.0). Do **not** force a different `com.android.billingclient` version in Gradle — a mismatch can return an empty catalog and leave prices as "Shown by your store account".
6. Set production AdMob app id:

```powershell
$env:ADMOB_ANDROID_APP_ID="ca-app-pub-XXXX~YYYY"
```

7. Build the Play App Bundle:

```powershell
flutter build appbundle --release `
  --dart-define=PELEVO_API_BASE_URL=https://pelevo.com/api/v1 `
  --dart-define=PELEVO_SENTRY_DSN=https://...@sentry.io/... `
  --dart-define=ADMOB_REELS_ANDROID_AD_UNIT_ID=ca-app-pub-XXXX/YYYY
```

Output: `build/app/outputs/bundle/release/app-release.aab`

Do **not** set `PELEVO_ALLOW_DEMO_IAP` or `PELEVO_ALLOW_HMAC_INTEGRITY` for store builds.

Play Console declarations to expect:

- Ads
- Location (approximate / precise) for listener region + Cast discovery
- Camera / microphone / photos (Reels)
- Notifications
- Foreground service: media playback
- Data safety: account info, location, device IDs, purchase history, crash logs, ads
- Account deletion: available in-app

---

## 3. iOS release build (App Store)

This version is **5.2.0 (36)** (`pubspec.yaml`). Bundle ID: `com.Podemeraldltd.pelevo`. Display name: Pelevo. Minimum iOS: **13.0**. Archives are **macOS + Xcode 16+** only.

### 3.1 One-time Apple setup

1. Apple Developer → Identifiers → `com.Podemeraldltd.pelevo` with:
   - Push Notifications
   - Sign in with Apple
   - Associated Domains
   - In-App Purchase
2. App Store Connect → new iOS app, bundle ID as above, SKU `pelevo-ios`.
3. Xcode → Runner → **Signing & Capabilities** → your team (Automatic). Debug uses `Runner/Debug.entitlements` (`aps-environment` = development). Archive/Release uses `Runner/Release.entitlements` (`aps-environment` = **production**).
4. Host Universal Links (HTTP 200, no redirect, `application/json`):
   - `https://pelevo.com/.well-known/apple-app-site-association`
   - Prefer the same file on `www` without a 301 (see [app-links.md](configuration/app-links.md))
   - Replace `TEAMID` in [apple-app-site-association.json](configuration/apple-app-site-association.json) with your 10-character Team ID
5. Copy `ios/Flutter/AdMob.xcconfig.example` → `ios/Flutter/AdMob.xcconfig` (gitignored) with the **production** iOS AdMob **app** id (`ca-app-pub-…~…`). Release builds fail if this is empty so sample ads never ship.
6. Copy `ios/dart_defines.release.json.example` → `ios/dart_defines.release.json` (gitignored) with production Sentry DSN and iOS native ad **unit** ids. Do **not** set `PELEVO_ALLOW_DEMO_IAP`, `PELEVO_ALLOW_HMAC_INTEGRITY`, or `ADMOB_USE_SAMPLE_UNITS`.
7. App Store Connect IAP (must match the app):
   - Auto-renewable: `pelevo_plus_monthly`, `pelevo_plus_yearly` (yearly intro: 1 month free)
   - Consumable coins: `coins_300`, `coins_500`, `coins_750`, `coins_1000`, `coins_1500`, `coins_2000`
8. Server `.env`: `APPLE_BUNDLE_ID=com.Podemeraldltd.pelevo` plus App Store Server API key (`APPLE_ISSUER_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY`).

### 3.2 Codemagic (preview, then App Store)

Preferred path when you do not have a Mac every day: [CODEMAGIC_IOS.md](CODEMAGIC_IOS.md).

1. Connect the App Store Connect API key in Codemagic as integration **Pelevo**.
2. Fill environment group **`pelevo_ios`**.
3. Run workflow **iOS Preview (TestFlight)** and install from TestFlight.
4. When that build is good, run **iOS App Store** (manual) or attach the same TestFlight build to 5.2.0 in App Store Connect.

### 3.3 Archive and upload (local Mac)

```bash
chmod +x ios/build_appstore.sh
./ios/build_appstore.sh
```

Or:

```bash
flutter pub get
cd ios && pod install && cd ..
flutter build ipa --release \
  --obfuscate \
  --split-debug-info=build/app/outputs/symbols \
  --export-options-plist=ios/ExportOptions.plist \
  --dart-define-from-file=ios/dart_defines.release.json
```

IPA: `build/ios/ipa/pelevo.ipa`. Upload with Transporter, Xcode Organizer, or `xcrun altool`. Keep `build/app/outputs/symbols` for crash symbolication.

You can also open **`ios/Runner.xcworkspace`** (not `.xcodeproj`), select **Any iOS Device**, **Product → Archive**.

Export compliance: `ITSAppUsesNonExemptEncryption` is `false` (HTTPS only). Answer “No” in App Store Connect if asked.

Privacy manifest: `ios/Runner/PrivacyInfo.xcprivacy` is in the app bundle. Match App Privacy answers (ads tracking, location, purchases, crash, IDs).

### 3.4 App Store Connect listing (this version)

| Field | Value |
|---|---|
| Name | Pelevo |
| Subtitle | Listen, earn, and create |
| Category | Entertainment (primary). Optional secondary: Music |
| Age | 13+ (unrestricted web, UGC Reels/comments, ads). Earn/cashout is 18+ in-app |
| Privacy policy | https://pelevo.com/privacy |
| Terms / EULA | https://pelevo.com/terms (or Apple standard EULA + this URL in Review Notes) |
| Support URL | https://pelevo.com |
| Marketing URL | https://pelevo.com |
| Copyright | © Pod Emerald Ltd |
| Encryption | Exempt (`ITSAppUsesNonExemptEncryption` = false) |

**Description (paste, then trim to 4000 characters):**

Pelevo is a podcast and short-video app. Listen to shows, follow creators, record Reels, and support them with gifts. Optional Pelevo Plus removes ads and unlocks member episodes. Coin packs and Plus are sold through Apple In-App Purchase. Listen-to-earn and cashout are available only where allowed, require age confirmation, and are not a guarantee of income.

**Review Notes:** Sign in with Apple on a new account. Plus and coin SKUs are auto-renewable / consumable as listed. Ads use Google AdMob after ATT/UMP. Location is when-in-use for listener region and Cast discovery; the app still plays if denied. Account deletion: Settings → Privacy & data → Delete my account. Demo account: provide a reviewer login if your API requires one.

**Screenshots:** 6.7" iPhone required. Because the binary is universal (`TARGETED_DEVICE_FAMILY` 1,2), also add 13" iPad. Show listening, Reels, and Plus without “get rich” earn claims.

**App Privacy (nutrition labels):** align with `PrivacyInfo.xcprivacy` — email/name/user ID (account), device ID + advertising data (tracking via ATT), coarse/precise location, purchase history, photos/video/audio (Reels), crash/performance (Sentry).

---

## 4. Policy-sensitive product notes (Pelevo)

1. **Listen-to-earn / cashout** — US-gated, 18+ confirmation in withdrawal flows. Do not market guaranteed income. Keep conversion rules honest in Earn Rules + Terms.
2. **Virtual gifts / coins** — purchased via Play Billing / StoreKit; balances are server-authoritative. No free seeded coin grants in production.
3. **Premium Plus** — store IAP only on mobile; restore purchases is available.
4. **Ads** — UMP consent → ATT (iOS) → Mobile Ads. Not tagged child-directed; general audience 13+.
5. **UGC (Reels / comments)** — ensure reporting/moderation stay enabled; disclose user-generated content in age ratings.
6. **Location** — disclosed for listener region analytics and Cast discovery; playback continues if denied.

---

## 5. Pre-upload smoke test

**Play rejection note (Broken Functionality / crash on open):** always sideload the
**signed release** AAB/APK (or `flutter run --release`) on a physical device before
uploading. Debug builds hide R8/AdMob ContentProvider crashes. Confirm
`ADMOB_ANDROID_APP_ID` is your real AdMob app id (not Google’s sample
`ca-app-pub-3940256099942544~3347511713`). Upload the release mapping file from
`build/app/outputs/mapping/release/` to Play Console for crash deobfuscation.

- [ ] Fresh install signed release build on physical Android + iPhone (TestFlight for iOS)
- [ ] Sign in with Google (Android) / Apple (iOS)
- [ ] Open Privacy Policy + Terms from About and Privacy & data
- [ ] Request data export; schedule account deletion (on a throwaway account)
- [ ] Buy Plus (sandbox) + restore
- [ ] Buy a coin pack (sandbox)
- [ ] Play episode with background audio; receive a test push
- [ ] Reels record/upload permission prompts show correct strings
- [ ] Ads load only with production unit ids (no Google sample creatives in release)
- [ ] CMS terms/privacy published on production

---

## 6. Screenshots & listing copy

Provide phone screenshots that show listening, earn (without overclaiming payouts), Reels, and creator studio. Avoid “get rich” claims. Match the privacy policy description of ads and location.
