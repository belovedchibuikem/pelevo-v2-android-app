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

## 3. iOS release build

1. In Xcode → Runner target → **Signing & Capabilities**, enable:
   - Push Notifications
   - Sign in with Apple
   - Associated Domains (`applinks:pelevo.com`, `applinks:www.pelevo.com`)
2. Copy `ios/Flutter/AdMob.xcconfig.example` → `ios/Flutter/AdMob.xcconfig` with the production iOS app id.
3. Archive:

```powershell
flutter build ipa --release `
  --dart-define=PELEVO_API_BASE_URL=https://pelevo.com/api/v1 `
  --dart-define=PELEVO_SENTRY_DSN=https://...@sentry.io/... `
  --dart-define=ADMOB_REELS_IOS_AD_UNIT_ID=ca-app-pub-XXXX/YYYY
```

Or open `ios/Runner.xcworkspace`, set a Release team, then **Product → Archive**.

Export compliance: `ITSAppUsesNonExemptEncryption` is `false` (standard HTTPS only). Confirm in App Store Connect if asked.

Privacy manifest: `ios/Runner/PrivacyInfo.xcprivacy` ships in the app bundle. Align App Privacy answers with it (ads tracking, location, purchases, crash, IDs).

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

- [ ] Fresh install signed release build on physical Android + iPhone
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
