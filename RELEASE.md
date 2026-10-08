# Pelevo release checklist

## Required dart-defines (release)

```bash
flutter build apk --release \
  --dart-define=PELEVO_API_BASE_URL=https://pelevo.com/api/v1 \
  --dart-define=PELEVO_SENTRY_DSN=https://...@sentry.io/... \
  --dart-define=PELEVO_EARN_INTEGRITY_SECRET=matching-server-EARN_INTEGRITY_TOKEN
```

Release builds default to `https://pelevo.com/api/v1` when `PELEVO_API_BASE_URL` is omitted.

- `PELEVO_API_BASE_URL` must be HTTPS and end with `/api/v1`.
- `PELEVO_SENTRY_DSN` enables crash/money tracing; omit to skip Sentry.
- `PELEVO_EARN_INTEGRITY_SECRET` is staging-only HMAC fallback. Prefer Firebase App Check / Play Integrity + `EARN_INTEGRITY_URL` in production.
- Never set `PELEVO_ALLOW_DEMO_IAP=true` or `PELEVO_ALLOW_HMAC_INTEGRITY=true` for store builds.
- `/catalog` is compiled out of release (`kDebugMode` only).

## Android signing

Create `android/key.properties` (not committed) and wire `signingConfigs.release` in `android/app/build.gradle.kts` before Play upload. Debug signing must not ship.

## Operator / QA gates (not completable in code alone)

1. Upload APNs Authentication Key (`.p8`) in Firebase Console → Cloud Messaging.
2. Prove killed-app FCM delivery on a physical iPhone and Android device.
3. Golden widget + physical-device acceptance of catalog routes.
4. Confirm CMS `terms` / `privacy` / `guidelines` published (migration `2026_09_11_100000_publish_cms_legal_pages` or admin CMS).
5. Set server `EARN_INTEGRITY_URL` (or `EARN_INTEGRITY_TOKEN` for staging HMAC) and `FCM_CREDENTIALS`.
6. Configure Google/Apple OAuth client IDs for Sign-In (`GOOGLE_IDENTITY_URL` / Apple identity).
7. `php artisan storage:link` so studio episode audio URLs resolve.
8. Forge Environment: `APP_URL=https://pelevo.com`, `SESSION_DOMAIN=.pelevo.com`.
