# Reels ad monetization runbook

## Safety defaults

- Keep `REELS_ADS_ENABLED=false` and `REELS_ADS_ALLOCATION_ENABLED=false` until the migration, queues, consent flows, and physical-device test checklist pass.
- `REELS_ADS_ENABLED=false` stops new server ad cycles. It does not delete or alter pending finance records.
- `REELS_ADS_ALLOCATION_ENABLED=false` permits shadow impression measurement without creating creator money.
- Never use Google test app IDs or test ad-unit IDs in a production build.
- Never enable a release build until the Android/iOS AdMob app IDs and Flutter `--dart-define` ad-unit IDs are supplied.

## Rollout

1. Apply the reels-ad migrations and verify rollback in a production-like copy.
2. Deploy the API with both flags off. Confirm finance workers and the scheduler are healthy.
3. Ship mobile builds using Google test IDs and complete UMP, ATT, native-layout, accessibility, background, rapid-swipe, and force-close testing on physical Android and iOS devices.
4. Enable `REELS_ADS_ENABLED` for shadow traffic while allocation remains off.
5. Compare valid views, due slots, watched/bounced ratios, SDK paid estimates, and AdMob reports.
6. Enable allocation for an internal cohort and execute the finance end-to-end test in non-production.
7. Record the legacy PCN cutover time. The legacy `AccrueReelRevenue` job must remain unscheduled.
8. Obtain finance, legal, Google Play Data Safety, and Apple App Privacy sign-off.
9. Roll out production IDs gradually. Watch the alerts below.

## Monthly settlement

1. Download the finalized USD amount from the AdMob Transactions page. Reporting API estimates are not finalized.
2. Calculate the source file SHA-256 and retain the file in the approved finance store.
3. In Admin → Finance → Reels ads, import the statement month, finalized USD micros, checksum, immutable source reference, timezone, and notes.
4. A different finance administrator approves the batch.
5. Approval reconciles pending allocations into confirmed USD. Reductions are balanced append-only ledger adjustments.
6. After the 30-day hold, confirmed funds release according to each creator's effective preference:
   - USD: 5% reserve in USD, remainder to USD available.
   - NGN: 5% reserve in USD, remainder converted once using a current approved USD/NGN rate and credited in NGN kobo.
7. Missing/stale FX, sanctions, or fraud review leave funds in confirmed USD for retry.

## FX operations

- Publish only audited USD→NGN rates in the existing FX desk.
- USD ad amounts use micros. NGN amounts use kobo.
- Each conversion creates balanced USD and NGN transactions and an immutable conversion record.
- Settle the USD and NGN clearing legs independently in the Reels ads desk using the external provider reference.
- Investigate any non-zero clearing balance outside the provider settlement window.

## Fraud review and corrections

- Review impressions in `fraud_state=review`. Clearing a record is blocked when creator ownership is missing or a creator self-view is present.
- Rejecting an unreleased impression reverses its pending creator entries with append-only ledger transactions.
- For a later clawback, use reserve deduction first. The action refuses to overdraw reserve.
- Reserve release always moves USD reserve to USD available; it never silently converts an existing balance.
- Recovery beyond reserve or recovery from already-paid/converted funds requires finance/legal approval and a dedicated recovery policy. Do not edit ledger balances or reuse a historic FX rate.

## Alerts

The hourly `MonitorReelAdMonetization` job emits:

- `reels_ad.health`
- `reels_ad.money_path_anomaly` (critical)
- `reels_ad.finance_attention_required` (warning)

Page finance/on-call for:

- stale pending impressions;
- watched impressions without allocations;
- allocations past hold without settlement;
- non-zero FX clearing outside the settlement window;
- material growth in the fraud-review backlog;
- ledger imbalance or queue failures;
- production test-ID use or missing production IDs;
- material divergence between watched callbacks, paid-event estimates, and AdMob reports.

## Emergency rollback

1. Set `REELS_ADS_ENABLED=false` to stop new due slots.
2. If money creation must also stop, set `REELS_ADS_ALLOCATION_ENABLED=false`.
3. Keep finance workers running so existing pending/confirmed records, expiry, reversals, and reconciliation remain recoverable.
4. Do not delete impressions, allocations, conversions, or ledger rows.
5. Capture the deployment time, affected app versions, flags, queue failures, and AdMob report window in the incident record.

## Release checklist

- [ ] Production Android AdMob app ID supplied as `ADMOB_ANDROID_APP_ID`.
- [ ] Production iOS app ID supplied in `ios/Flutter/AdMob.xcconfig`.
- [ ] Production Android/iOS native unit IDs supplied as Flutter dart defines.
- [ ] AdMob mediation partners selected and their privacy/store requirements completed.
- [ ] Current Google SKAdNetwork list reviewed against the official iOS quick-start.
- [ ] UMP geography/debug tests and ATT denial path passed.
- [ ] Android TalkBack and iOS VoiceOver/Dynamic Type tests passed.
- [ ] Real-ad requests were never used in automated tests.
- [ ] Finance end-to-end test and maker-checker test passed.
- [ ] Terms, Privacy Policy, Data Safety, and App Privacy were approved.
