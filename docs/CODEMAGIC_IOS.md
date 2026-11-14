# Pelevo iOS on Codemagic — preview, then App Store

Two workflows in `codemagic.yaml`:

1. **iOS Preview (TestFlight)** — signed IPA **uploaded** to App Store Connect. After Apple processes it (often 5–15 minutes), it appears on TestFlight for **internal** testers (App Store Connect users). This does not start Beta App Review or App Review.
2. **iOS App Store** — same compile path, then submits **5.2.0** for App Review. Run this only after preview is good **and** App Store Connect already has screenshots, privacy, and age rating. If those are empty, Apple rejects the *submit* step even though the IPA compiled. `release_type: MANUAL` means you tap **Release** after Apple approves.

Do not commit AdMob ids, Sentry DSNs, or API keys. They live in Codemagic.

## 1. Apple (once)

1. [Apple Developer](https://developer.apple.com/account) → Identifiers → `com.Podemeraldltd.pelevo` with Push, Sign in with Apple, Associated Domains, In-App Purchase.
2. App Store Connect → Users and Access → Integrations → **App Store Connect API** → generate a key with **App Manager**.
   - Download the `.p8` (once).
   - Note Key ID and Issuer ID.
3. App Store Connect → Apps → Pelevo must already exist with that bundle ID (create the app record if needed, even as a draft).
4. Internal testers: Users and Access → add yourself as an App Store Connect user, then Testers on the TestFlight tab.

## 2. Codemagic (once)

1. [codemagic.io](https://codemagic.io) → add this Git repo → **Workflow Editor is YAML** (`codemagic.yaml` in the project root).
2. **Teams → Integrations → App Store Connect** → upload the `.p8`, Key ID, Issuer ID.  
   Name the integration exactly **`Pelevo`** (matches `integrations.app_store_connect` in YAML).
3. App → **Environment variables** → group name **`pelevo_ios`** (secure):

| Variable | Value |
|---|---|
| `ADMOB_IOS_APP_ID` | Production iOS *app* id `ca-app-pub-…~…` |
| `ADMOB_REELS_IOS_AD_UNIT_ID` | Production native unit |
| `ADMOB_HOME_IOS_AD_UNIT_ID` | Production native unit |
| `ADMOB_SEARCH_IOS_AD_UNIT_ID` | Production native unit |
| `PELEVO_API_BASE_URL` | `https://pelevo.com/api/v1` |
| `PELEVO_SENTRY_DSN` | Live Sentry DSN (optional but recommended) |

Do **not** add `PELEVO_ALLOW_DEMO_IAP`, `PELEVO_ALLOW_HMAC_INTEGRITY`, or `ADMOB_USE_SAMPLE_UNITS`.

4. Start a **mac_mini_m2** build (included in YAML). First CocoaPods fetch can take 20–40 minutes.

## 3. Preview first

Do not run **iOS App Store** until this workflow is green and you have installed the build.

1. Codemagic → this app → **Start new build** → workflow **iOS Preview (TestFlight)**.
2. The build is **120 minutes** max (first CocoaPods fetch is slow). Wait until **publishing** is green, not only the compile step.
3. Codemagic bumps `CFBundleVersion` past the latest TestFlight/App Store number (from 36 upward). Marketing version stays **5.2.0**.
4. iPhone → TestFlight (same Apple ID as App Store Connect) → Pelevo. Check:
   - Sign in with Apple
   - Play an episode in background
   - Privacy / Terms links
   - Plus / coins only if those IAPs are **Ready to Submit** (sandbox)
   - Ads only if production unit ids are set (no Google sample creatives)
4. Download the IPA from the build’s **Artifacts** if you need a copy. dSYMs are under `build/app/outputs/symbols`.

If signing fails, the App Store Connect integration cannot create profiles until the App ID capabilities above exist.

## 4. Then App Store

1. Codemagic → **Start new build** → workflow **iOS App Store** (manual only).
2. Codemagic uploads a new build, waits for processing, attaches it to TestFlight, and submits **5.2.0** for review.
3. App Store Connect → complete screenshots, privacy nutrition labels, age rating, and IAP attachment if Apple asks.
4. After **Approved**, tap **Release this version** (manual release).

You can skip the second workflow and, in App Store Connect, add the TestFlight build you already previewed to the 5.2.0 version and submit there. Use `ios-app-store` when you want Codemagic to submit for you.

## 5. What the YAML does

- Automatic signing via the **Pelevo** integration (`distribution_type: app_store`).
- Writes `ios/Flutter/AdMob.xcconfig` on the builder so Release does not use the sample AdMob app id.
- `flutter build ipa` with production `--dart-define`s and obfuscation.
- Signing follows Codemagic’s Flutter sample: `pod install` → `xcode-project use-profiles` → `flutter build ipa --export-options-plist=$HOME/export_options.plist`.
- Preview publishing: **upload only** (internal TestFlight after Apple processes the binary).
- Store publishing: App Review for 5.2.0. Encryption **no**, IDFA **yes** (ATT + AdMob), UGC **yes**. Fill the listing before this workflow.

## 6. Optional TestFlight group

After you create a group (e.g. `Internal Testers`) in App Store Connect, add under `publishing.app_store_connect` in both workflows:

```yaml
beta_groups:
  - Internal Testers
```

Until then, App Store Connect users with access still see the build on TestFlight.
