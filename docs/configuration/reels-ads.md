# Reels ads configuration

## Server

All finance units are integers:

- USD ledger amounts: micros (`1 USD = 1,000,000`).
- NGN ledger amounts: kobo (`1 NGN = 100`).
- FX rates: decimal NGN per USD.

Required server settings are documented in `api/.env.example`. Important defaults:

- `REELS_ADS_ENABLED=false`
- `REELS_ADS_ALLOCATION_ENABLED=false`
- valid view `30000` ms
- deduplication `24` hours
- random cycle threshold `5` through `8`
- pending impression TTL `600` seconds
- creator pool `200` USD micros per watched impression
- hold `30` days
- reserve `500` basis points
- settlement timezone `America/Los_Angeles`
- supported release/payout currencies: USD and NGN only

Use Redis for the production cache and lock drivers. The cycle service requires shared, atomic cache locks across API instances.

## Android

- Debug builds use Google's sample AdMob app ID and native test unit.
- Release builds read `ADMOB_ANDROID_APP_ID` from the build environment.
- Pass the production native unit at build time:

```text
--dart-define=ADMOB_REELS_ANDROID_AD_UNIT_ID=ca-app-pub-.../...
```

Do not ship when the release app ID or unit ID is missing. Do not replace a missing production value with a test ID.

## iOS

Copy `ios/Flutter/AdMob.xcconfig.example` to the uncommitted/secret-managed `ios/Flutter/AdMob.xcconfig` and set the production app ID. Pass the production native unit:

```text
--dart-define=ADMOB_REELS_IOS_AD_UNIT_ID=ca-app-pub-.../...
```

The checked-in SKAdNetwork list follows Google's iOS quick-start as reviewed on 2026-09-30. Recheck it whenever Google Mobile Ads or mediation partners change.

## Consent and privacy

- UMP consent information is refreshed at every launch.
- Required UMP forms are shown before ads are initialized.
- On iOS, ATT is requested only after the UMP step; denial does not block permitted ads.
- The in-app privacy-options entry is shown only when UMP reports it as required.

AdMob console privacy messages, mediation-partner declarations, Google Play Data Safety, and Apple App Privacy are release operations and cannot be generated from source-code credentials.

## Release-time FX

NGN conversion requires an approved `fx_rate_versions` row with base `USD`, quote `NGN`, and an age no greater than `REELS_ADS_FX_QUOTE_MAX_AGE_MINUTES`. A stale or missing quote leaves the allocation in confirmed USD and the hourly release job retries it. Clients never submit an FX rate.
