# Task: Reels ad monetization for Android and iOS

## Objective

Implement production-ready, ad-funded creator payouts for the Flutter Reels feed on Android and iOS.

The implementation must:

- count a valid reel view only after 30 seconds watched, or 100% completion when the reel is shorter than 30 seconds;
- count at most one valid view per user and reel in a rolling 24-hour period;
- choose a random ad threshold of 5–8 valid views for each feed cycle;
- insert a full-screen 9:16 Native Advanced ad as the next inline feed item;
- never use an interstitial, banner, app-open, or rewarded ad;
- create creator attribution when the threshold is reached, but create money only after `onAdImpression` fires;
- split the USD 0.0002 impression pool proportionally by each creator's eligible reel count;
- hold creator credits for 30 days, reconcile them to finalized AdMob earnings, retain a configurable reserve, and expose only released funds for payout;
- support creator payout balances and payouts in both United States dollars (USD) and Nigerian naira (NGN);
- support fraud review, reversals, idempotent retries, operational monitoring, and emergency shutdown;
- use AdMob test ad units in development and automated testing.

## Confirmed product decisions

- Ad format: Native Advanced only.
- Placement: inline, full-screen 9:16 Reels feed item with the same vertical swipe behavior as a reel.
- Trigger: a random threshold from 5 through 8 valid views, inclusive.
- Impression pool: USD 0.0002 per confirmed ad impression.
- Attribution: proportional by eligible reel count per creator in the completed cycle.
- No impression means no creator credit.
- Hold: 30 days.
- Reserve: 5% by default, configurable by an authorized administrator and periodically trued up.
- Reconciliation: audited monthly import of finalized totals from the AdMob Transactions page; the AdMob Reporting API may be used only for estimated comparison data.
- Ledger: separate currency-qualified ad-revenue subledgers for USD and NGN; do not convert ad share to PCN.
- Payout currencies: creators can select USD payout or NGN payout.
- Currency conversion: AdMob revenue remains in USD through pending, reconciliation, confirmation, and reserve calculation. At release, the creator's available portion is either posted to the USD available ledger or converted into the NGN available ledger using an approved, audited FX rate.
- Currency preference changes: apply only to future releases; do not silently convert existing available balances.
- Reserve currency: keep the 5% reserve in USD so AdMob USD clawbacks can be reconciled without introducing FX gains or losses.
- Abandoned pending impression: expire as bounced after a configurable 10-minute default TTL.

## Current repository state and required replacement

The current implementation is not the requested ad-funded model:

- Flutter sends cumulative `watched_ms` to `POST /reels/{id}/view-heartbeat`.
- The server defaults to a 3-second qualified-view threshold and a 60-minute duplicate window.
- `reel_view_credits` currently feed the hourly `AccrueReelRevenue` job.
- `AccrueReelRevenue` immediately credits PCN from `reel_revenue_funding`.
- There is no mobile ads SDK, native ad factory, ad impression API, attribution snapshot, USD/NGN ad-revenue ledger, finalized settlement import, FX conversion workflow, or reserve workflow.
- Reels feeds are SQL/client list based; there is no existing Redis Reels feed queue.

Replace the immediate PCN reel-view accrual path for ad revenue. It must not run in parallel with the new pipeline because that would double-pay creators. Preserve unrelated gifts, Earn, podcast monetization, and PCN behavior.

## Scope

### Flutter

- AdMob/Google Mobile Ads initialization.
- UMP consent and privacy-options flow.
- Android and iOS Native Advanced factories.
- Mixed reel/ad feed items.
- Server-directed ad placement.
- Ad lifecycle, disposal, retry, and impression reporting.
- Foreground, audible playback heartbeats.
- Creator Studio USD and NGN ad-revenue presentation and payout-currency selection.

### Laravel

- Server-authoritative valid-view processing.
- Rolling 24-hour deduplication.
- Redis cycle state and random threshold.
- Ad impression and attribution snapshots.
- Idempotent impression confirmation.
- USD source allocation plus USD/NGN release and payout accounting.
- Reconciliation, reserve, release, adjustment, and reversal workflows.
- Admin settlement import and approval.
- Fraud signals and review blocking.
- Scheduler, queue, configuration, audit, metrics, and alerts.

### Mobile platforms

- Android AdMob application ID and native layout/factory registration.
- iOS AdMob application ID, ATT usage copy/framework, native view/factory registration, and required SKAdNetwork configuration from the current Google documentation.
- Store-safe consent and privacy disclosures.

## Explicit non-goals

- Interstitial, banner, app-open, or rewarded advertising.
- Paying for ad clicks.
- Paying when an ad merely loads or is requested.
- Watch-time-weighted creator allocation.
- Creator payout from estimated AdMob reporting.
- Client-authored payout amounts or valid-view decisions.
- Real ads in automated tests.
- Rewriting the whole Reels feed into a Redis queue.
- Changing podcast Earn, gifts, or unrelated creator revenue.

## Data model

Use decimal/integer money representations only. Store USD amounts as integer micros and NGN amounts as integer kobo wherever practical; never use binary floating point. Every account and ledger entry must carry one explicit ISO 4217 currency (`USD` or `NGN`), and a single balanced ledger transaction must never mix currencies.

### 1. Reel view heartbeat audit

Create `reel_view_heartbeats` or an equivalent append-only audit table:

- `id` ULID/UUID primary key
- `reel_view_id`
- `user_id`
- `reel_id`
- `session_id`
- `sequence`
- `received_at`
- `playback_position_ms`
- `server_counted_ms`
- `completed`
- `app_foreground`
- `audible`
- `integrity_result`
- `ip_hash` and `device_hash` using the existing privacy-safe conventions
- timestamps

Enforce uniqueness on `(reel_view_id, sequence)` and reject replayed/out-of-order sequences without adding watch time.

Extend or migrate `reel_views` to include:

- `is_valid_view` boolean, server controlled
- `counted_at` timestamp nullable
- server-accumulated watch duration
- completion timestamp nullable
- integrity/fraud state

Keep legacy `qualified`/`qualified_at` only during a safe migration period. Update all readers, then remove or formally deprecate them.

Add an index supporting the rolling dedup lookup:

- `(user_id, reel_id, counted_at)`

The valid-view transition must run under a database transaction and a lock scoped to the user/reel pair so concurrent sessions cannot both pass the rolling 24-hour check.

### 2. Ad impressions

Create `ad_impressions`:

- `id` UUID primary key
- `user_id`
- `feed_session_id`
- `installation_hash`
- `platform` (`android` or `ios`)
- `ad_unit_key`
- `triggered_at`
- `expires_at`
- `watched_at` nullable
- `bounced_at` nullable
- `status` (`pending`, `watched`, `bounced`)
- `threshold`
- `eligible_view_count`
- `payout_pool_usd_micros`, default/config snapshot equivalent to USD 0.0002
- `reserve_bps`, configuration snapshot
- estimated paid-event value, currency, and precision nullable
- client event id/idempotency key nullable
- fraud/review state
- reconciliation batch id nullable
- timestamps

Do not accept a payout pool or reserve rate from the client.

Create `ad_impression_attributions`:

- `ad_impression_id`
- `reel_id`
- `creator_profile_id`
- `reel_view_id`
- `counted_at`
- timestamps

Use `(ad_impression_id, reel_view_id)` as the uniqueness boundary. The allocation query groups these immutable rows by creator. A reel/view may belong to only one completed ad cycle.

If the product requires the originally proposed `(ad_impression_id, reel_id)` primary key, also ensure a reel cannot appear twice in one cycle. `reel_view_id` must still be retained for auditability.

### 3. USD and NGN ad-revenue ledgers

Build on the existing append-only finance pattern without writing balances directly.

Add currency-qualified ad-revenue accounts/subaccounts and immutable ledger entries that can represent:

- `pending`
- `confirmed`
- `reserve`
- `available`
- `fx_clearing`
- `fx_gain_loss`
- `adjustment`
- `reversal`

Each creator allocation must reference:

- creator profile;
- ad impression;
- reconciliation batch when applicable;
- ISO currency;
- gross USD micros;
- reserve USD micros;
- available amount in the ledger entry's currency and minor unit;
- currency conversion id when an NGN amount was produced from USD;
- effective status and timestamps;
- idempotency key.

Use balanced transactions through a multi-currency-compatible extension of the existing ledger action. Each individual posting balances within one currency. A USD-to-NGN conversion is represented by two separately balanced, atomically linked transactions through currency-specific FX clearing accounts. Database immutability triggers must cover the new entries. Corrections are new reversing/adjusting entries, never updates to posted money.

Creator payout selection must include only the matching-currency `available` account. USD payout batches select only USD available funds; NGN payout batches select only NGN available funds. Neither may include `pending`, `confirmed`, `reserve`, or the other currency.

### 4. FX conversions and payout-currency preference

Extend creator payout settings with:

- `ad_payout_currency`, restricted to `USD` or `NGN`;
- preference effective timestamp;
- last changed by/at and audit metadata.

Defaulting or migration of existing creators must follow the creator's existing payout currency where it is already valid. Otherwise, require an explicit choice before the first release; do not guess a payout currency.

Create immutable `currency_conversions` or an equivalent auditable conversion record:

- id;
- creator profile id;
- source ledger transaction id;
- source currency (`USD`);
- source amount in USD micros;
- destination currency (`NGN`);
- destination amount in NGN kobo;
- quoted rate as an exact decimal/rational value;
- rate provider/source;
- provider quote/reference id when available;
- quote timestamp and expiry;
- applied spread/fee and net rate, if any;
- approved by/at when the rate is manually supplied;
- conversion reason (`ad_revenue_release`, `reversal`, or `adjustment`);
- idempotency key;
- timestamps.

At release:

1. Snapshot the creator's effective payout-currency preference.
2. Calculate and retain the 5% reserve in USD.
3. For USD preference, move the releasable 95% into the creator's USD available account.
4. For NGN preference, convert the releasable 95% once at the approved release-time rate and post the result into the creator's NGN available account through linked USD and NGN FX-clearing transactions.
5. Store enough rate and rounding detail to reproduce the exact NGN kobo amount.

The client may select a supported payout currency but may never submit or override an FX rate. Changing preference affects only future releases. Existing USD and NGN available balances stay in their original currency unless a separate, explicitly authorized conversion feature is later approved.

### 5. Settlement batches

Create an audited AdMob reconciliation batch model:

- statement month and AdMob account identifier;
- account timezone and source currency, expected to be USD for this implementation;
- imported finalized gross amount;
- associated estimated amount and report metadata when available;
- adjustment/invalid-traffic amount;
- source file checksum or immutable source reference;
- imported by, reviewed by, approved by, and timestamps;
- status (`draft`, `validated`, `approved`, `posted`, `reversed`);
- notes and reason codes.

Prevent duplicate approved batches for the same AdMob account and statement month. Import and approval must be separate permissions/actions.

## Server-authoritative valid-view protocol

1. Flutter creates a unique playback session identifier when a reel becomes active.
2. While the video is playing, audible, visible, and the app is foregrounded, Flutter sends a heartbeat at the configured interval.
3. Flutter pauses heartbeats immediately when playback pauses, the reel is no longer active, the app backgrounds, or audio is muted.
4. The payload includes session id, monotonic sequence, playback position, and completion state. It does not include trusted elapsed or payout values.
5. Laravel records the receipt and computes the countable interval from server receipt times, bounded by the configured heartbeat interval/grace and consistent playback-position progress.
6. Replayed, impossible, background, muted, too-fast, or stale heartbeats add no watch time and create a fraud signal where appropriate.
7. A view becomes eligible at:
   - at least 30,000 server-counted milliseconds for reels of 30 seconds or longer; or
   - verified completion for reels shorter than 30 seconds.
8. Before setting `is_valid_view`, Laravel checks for an existing `counted_at` in the rolling previous 24 hours for the same user and reel.
9. Duplicate watches remain available for analytics but never update the ad counter or attribution.
10. The valid transition is one-way and emits one idempotent domain event.

Reuse the existing Earn integrity approach where applicable, but do not treat a client secret as sufficient proof. Continue using authenticated users and the existing installation/device header. Record enough server evidence to investigate abuse.

## Redis ad-cycle state

Implement only the per-feed-session ad-cycle state required by this feature; do not claim an existing Redis Reels queue exists.

For each authenticated user/feed session, store:

- current random threshold, generated with a cryptographically safe server-side integer from 5–8;
- count of accepted valid views in this cycle;
- ordered set/list of eligible `reel_view_id` values;
- cycle identifier;
- timestamps and TTL;
- whether an ad is already due/pending.

Requirements:

- Increment only from the one-way server valid-view event.
- Make increment/threshold evaluation atomic with a Lua script, transaction, or equivalent.
- Ignore duplicated event delivery.
- When the threshold is reached, atomically freeze the cycle and create the database impression plus attribution snapshot.
- Do not reset/drop the contributing batch until the database snapshot succeeds.
- Return an `ad_due` instruction containing only the server impression id and safe rendering metadata.
- Start a new random cycle after the prior cycle is frozen.
- Prevent simultaneous devices/tabs from paying the same valid views twice.
- Use explicit TTLs and recovery logic; Redis eviction must not create creator money or lose an already persisted impression.

## API contract

Version and document all changed endpoints in the OpenAPI contract.

### Heartbeat

Update:

`POST /v1/reels/{reel}/view-heartbeat`

Request:

- `session_id`
- `feed_session_id`
- monotonic `sequence`
- `playback_position_ms`
- `completed`
- app foreground/audible state needed for validation

Response:

- accepted/rejected heartbeat result;
- current server-counted progress without exposing fraud internals;
- whether this request caused a new valid view;
- optional `ad_due` object with `ad_impression_id`, expiry, and platform-safe ad-unit key.

The endpoint must be authenticated, rate limited, sanctioned-user aware, idempotent, and protected by the existing device/integrity mechanisms.

### Impression confirmation

Add:

`POST /v1/reels/ad-impressions/{adImpression}/watched`

Requirements:

- accept only the owner user/session/device context;
- require a unique client event id;
- reject expired, bounced, already consumed, wrong-platform, or mismatched-session records;
- be idempotent for the same event;
- transition `pending` to `watched` exactly once;
- set `watched_at` from server time;
- enqueue creator allocation only after commit;
- never accept payout amounts from the client.

The Flutter `NativeAdListener.onAdImpression` callback is the trigger for this request. `onAdLoaded` is not a payable event.

### Optional estimated paid event

If `NativeAdListener.onPaidEvent` is available for the AdMob account, report it to a separate idempotent endpoint as observability/estimate data. It must never independently create, release, or increase creator funds.

### Bounce handling

- `onAdFailedToLoad`, explicit feed-session shutdown, or a known skip may request an idempotent bounce transition.
- A scheduled job marks any still-pending impression as `bounced` after the configured 10-minute TTL.
- A late impression callback after expiry creates no credit and is logged for investigation.
- `bounced` impressions retain attribution rows for audit but distribute no money.

## Creator allocation

Run only after a committed `pending -> watched` transition.

For one impression:

1. Count immutable attribution rows grouped by `creator_profile_id`.
2. Let `total_count` be all eligible attributed views.
3. Allocate `payout_pool_usd_micros * creator_count / total_count`.
4. Use deterministic largest-remainder rounding so all creator allocations sum exactly to the impression pool.
5. Insert one idempotent pending USD ledger allocation per creator.
6. Expose the pending amount in Creator Studio immediately.

Example: with three eligible views, two from creator A and one from creator B, A receives two thirds and B receives one third, with deterministic micro-unit rounding.

If an attribution has no valid creator owner, quarantine the impression for review rather than reallocating silently.

## Hold, reconciliation, reserve, and payout

### Immediate pending credit

- A watched impression creates visible `pending` USD ledger entries.
- Pending funds are not withdrawable or selectable by payout batches.
- The UI shows the hold date, that the amount is estimated, and an indicative NGN value only when clearly labelled non-final.
- Pending and confirmed values remain denominated in USD until release; showing an NGN estimate must not create an NGN ledger entry.

### 30-day hold

- A daily job finds unreconciled pending allocations at least 30 days old.
- Age alone must not release money.
- Release requires an approved finalized settlement batch covering the earning period.
- Fraud review, sanctions, or unresolved attribution issues block release.

### Monthly reconciliation

- Fetch/store AdMob API estimated reports for comparison if credentials are configured.
- Do not label API report earnings as finalized.
- An authorized finance operator imports the finalized amount from the AdMob Transactions page and a second authorized operator approves it.
- Validate statement period, timezone, currency, duplicate imports, negative adjustments, and source checksum.
- Compute the maximum releasable creator pool from finalized collected revenue and the configured commercial share.
- If finalized revenue is lower than accumulated pending allocations, scale eligible confirmed amounts down proportionally and post append-only adjustment entries.
- Never release more than Pelevo actually collected for the reconciled scope.
- If finalized revenue is higher, do not increase the fixed USD 0.0002 creator pool unless a future approved product change explicitly allows it.

### Reserve

- On release, move 5% by default from confirmed into the creator's USD reserve account.
- Route the remaining 95% to USD available or convert it once into NGN available according to the creator's effective payout-currency preference.
- Snapshot the applied basis points on every release.
- For an NGN release, snapshot the approved FX source, gross rate, spread/fee, net rate, quote timestamp, source USD micros, rounding result, and destination NGN kobo.
- Changing the configuration affects future releases only unless an explicit audited true-up is posted.
- Provide an audited true-up action to move reserve to available or apply later deductions.
- Never mutate prior ledger rows.

### Later clawbacks

- Post proportional negative adjustments against reserve first.
- Because reserve is held in USD, apply AdMob USD clawbacks against USD reserve first.
- If reserve is insufficient, offset future USD-confirmed earnings before release according to payout/legal policy.
- If recovery from an already converted NGN available balance is legally required, post a linked, audited reverse FX adjustment using the approved recovery-rate policy; do not reuse the historic conversion rate silently or create a direct balance edit.
- Flag material negative balances for finance review.

## Flutter feed implementation

Refactor the feed item model into an explicit sealed/typed model:

- reel item;
- native ad slot item.

Requirements:

- The server's `ad_due` instruction inserts the ad slot immediately after the reel that completed the threshold.
- Maintain independent cycle/session state for the active feed session while ensuring the server remains authoritative.
- Never increment based on page changes or raw scrolls.
- Preload at most the next due native ad without reporting it as watched.
- Render a loading/fallback state that does not block feed scrolling.
- If ad loading fails, remove/skip the slot safely, report bounce when possible, and continue the feed.
- Dispose each `NativeAd` after its widget leaves the retained feed window or fails to load.
- Prevent the same `NativeAd` object from being mounted in multiple `AdWidget`s.
- Do not autoplay or simulate interaction with ad assets.
- Pause reel playback while the ad page is active and resume normal reel behavior after the user swipes away.
- Preserve deep links, saved reels, creator reel feeds, preload/eviction, hidden items, and existing three feed tabs.
- Decide one product-wide eligibility boundary: ad-funded cycles run only in the primary Reels browsing surfaces that use the server feed-session contract. Do not accidentally trigger ads from creator preview, draft, or management screens.

Create an ad service abstraction so widget and integration tests use a fake provider and never contact live AdMob.

## Native Advanced rendering

Use the current stable `google_mobile_ads` package compatible with the project's Flutter/Dart constraints and commit the resolved lockfile.

Use `NativeAd` with a shared factory id registered independently on Android and iOS. Handle:

- `onAdLoaded` for render readiness only;
- `onAdFailedToLoad` for disposal and bounce handling;
- `onAdImpression` for the idempotent watched request;
- `onPaidEvent` for estimate telemetry only;
- click/open/close callbacks for analytics only.

The 9:16 view must:

- clearly display required ad attribution and AdChoices;
- map all supplied native assets to the platform native ad view;
- preserve SDK-controlled click handling;
- avoid placing app controls over clickable ad assets;
- meet Google native ad layout, accidental-click, and minimum-size policies;
- use safe areas and adapt to supported phone dimensions;
- provide accessibility labels, Dynamic Type/font scaling, and dark/light contrast;
- keep the same vertical paging gesture as reel items.

## Android work

- Add the production AdMob app ID through environment/flavor-safe resources; use Google's sample/test app ID in test/demo builds.
- Add `com.google.android.gms.ads.APPLICATION_ID` metadata to the application manifest.
- Implement a Kotlin `NativeAdFactory` producing a full-screen `NativeAdView`.
- Add the 9:16 Android layout/resources and required asset views.
- Register/unregister the factory in the Flutter engine lifecycle with the exact shared factory id.
- Initialize Mobile Ads only after consent permits ad requests.
- Confirm Gradle/minSdk compatibility and release shrinking/obfuscation behavior.
- Add network security/config only if required by official SDK documentation.
- Validate rotation policy, process recreation, low-memory disposal, TalkBack, and Android back behavior.

## iOS work

- Add the production `GADApplicationIdentifier` through build-configuration-safe values; use Google's sample/test ID in test/demo builds.
- Add the current Google-provided SKAdNetwork identifiers required for the selected SDK/mediation setup.
- Add `NSUserTrackingUsageDescription` with approved legal/product copy.
- Link AppTrackingTransparency where required.
- Implement and register a Swift `FLTNativeAdFactory` that returns a full-screen `GADNativeAdView`.
- Set explicit width/height constraints so `AdWidget` renders correctly.
- Map all native assets, AdChoices, and accessibility behavior.
- Initialize Mobile Ads only after the consent flow permits ad requests.
- Validate factory lifecycle, memory disposal, safe areas, VoiceOver, Dynamic Type, and foreground/background transitions.

ATT denial must not block the app. Request non-personalized/limited ads as permitted by consent and SDK policy.

## Consent, privacy, and store compliance

- Integrate Google UMP.
- Call consent-information update on every app launch.
- Load/show required consent forms before requesting ads.
- Check `canRequestAds()` before Mobile Ads initialization/ad loading.
- Provide the required persistent privacy-options entry point when UMP says it is required.
- Configure and test EEA/UK consent, California/US privacy messages, under-age treatment where applicable, and consent reset/debug devices.
- Show the GDPR/consent flow before ATT when both apply.
- Update Privacy Policy and in-app disclosures for AdMob, mediation partners, device identifiers, impression/revenue telemetry, retention, creator attribution, fraud review, and data rights.
- Verify Terms still match the exact USD pool, proportional split, hold, USD reserve, USD/NGN release conversion, reconciliation, FX fees/spread, clawback, and payout behavior.
- Complete Google Play Data Safety and Apple App Privacy declarations before release.
- Keep secrets, OAuth refresh tokens, and AdMob account credentials server-side.

Legal copy changes require legal/product approval; implementation must not invent copy.

## Fraud and abuse controls

- Server receipt-time heartbeat accumulation.
- Rolling 24-hour user/reel deduplication.
- Monotonic heartbeat sequence and bounded timing.
- Authenticated user, installation/device, session, IP-hash, and integrity correlation.
- Exclude creator self-views from payable attribution unless product/legal explicitly approves them.
- Flag impossible rates, including reaching the cycle threshold in implausible wall-clock time.
- Flag repeated accounts/devices/IP clusters disproportionately viewing one creator.
- Flag impression callback rates inconsistent with SDK paid/impression/reporting data.
- Block allocation/release for sanctioned users, fraudulent sessions, or quarantined creators.
- Keep thresholds and exact fraud rules out of client-visible responses where possible.
- Add admin review actions with reason codes and audit logs.
- Use the 30-day hold to reverse invalid pending entries before release.

Do not silently confiscate funds. Every block, adjustment, and reversal needs an auditable reason and authorization.

## Admin and Creator Studio

### Creator Studio

Display ad revenue separately from PCN and group every amount by currency:

- USD pending;
- USD confirmed awaiting release;
- USD reserve;
- USD available for payout;
- NGN available for payout;
- adjustments/reversals;
- estimated release date;
- selected future payout currency (`USD` or `NGN`);
- the exact conversion rate, source, timestamp, fee/spread, source USD amount, and resulting NGN amount for each completed conversion;
- transaction detail linked to an anonymized impression/cycle reference.

Allow the creator to select USD or NGN for future ad-revenue releases, subject to existing payout-account eligibility and verification. Confirm that changing the selection does not convert existing balances.

Do not combine USD and NGN into one numeric balance. A converted/indicative total may be shown only with its rate timestamp and a clear estimate label. Do not present estimates as finalized or payable.

### Admin finance

Add permissioned workflows for:

- estimated AdMob report sync status;
- finalized monthly statement import;
- validation preview;
- dual approval and posting;
- reconciliation differences;
- USD/NGN payout-currency configuration;
- approved FX rate sources, quote freshness, spread/fee, and manual-rate dual approval;
- FX conversions and clearing-account reconciliation;
- reserve configuration and true-up;
- clawback/reversal;
- blocked/fraud-reviewed creator allocations;
- downloadable audit trail.

All finance actions require idempotency, authorization, actor identity, timestamps, reason codes, and immutable audit records.

## Configuration and secrets

Document safe environment/config values:

- feature flag and global kill switch;
- Android/iOS AdMob app IDs;
- Android/iOS native ad unit IDs;
- test-mode enforcement outside production;
- valid-view threshold (30 seconds) and rolling window (24 hours);
- heartbeat interval and grace;
- ad threshold minimum/maximum (5/8);
- pending impression TTL (10 minutes default);
- impression pool USD micros (200 micros);
- hold days (30);
- reserve basis points (500);
- AdMob API account/OAuth secret references;
- AdMob settlement timezone and source currency (USD);
- supported creator payout currencies (`USD`, `NGN`);
- USD-to-NGN FX provider/source and credential references;
- maximum FX quote age;
- approved FX spread/fee basis points;
- conversion rounding mode and NGN minor-unit scale;
- manual FX fallback and dual-approval requirement;
- fraud-rate thresholds;
- queue names and retry policies.

Validate production startup so missing production AdMob identifiers disables ads safely instead of crashing. Never fall back to test IDs in a production build, and never use live IDs in automated tests.

## Jobs and scheduling

Add idempotent queued jobs for:

- creator allocation after watched impression;
- stale pending impression expiry;
- estimated AdMob report retrieval, if configured;
- 30-day hold eligibility;
- approved settlement posting and proportional adjustment;
- reserve release/true-up and payout-currency routing;
- USD-to-NGN release conversion;
- stale/failed FX quote retry without duplicate conversion;
- USD and NGN FX-clearing reconciliation;
- fraud scoring;
- operational reconciliation between impressions, attribution rows, and ledger entries.

Use the existing finance queue/Horizon conventions, `onOneServer` where required, explicit retry/backoff, dead-letter/failure visibility, and transaction-after-commit dispatch.

Disable/remove the scheduled `AccrueReelRevenue` path for ad-funded reel views after migration.

## Migration and rollout

1. Add schema, models, services, APIs, feature flags, and disabled-by-default configuration.
2. Deploy heartbeat changes in a backward-compatible observation mode.
3. Ship Flutter with test ads and both native factories.
4. Verify consent and test-device behavior on physical Android and iOS devices.
5. Stop new legacy PCN reel-view accrual at a recorded cutover timestamp.
6. Reconcile or preserve historical legacy entries; never silently convert historical PCN to USD or NGN.
7. Enable impression collection in shadow mode with creator allocation disabled.
8. Compare callback counts, bounce rates, AdMob estimated impressions, fraud flags, and feed stability.
9. Enable pending USD allocations plus test USD/NGN release routing for an internal cohort.
10. Validate a shortened hold window only in non-production.
11. Complete finance/legal/store review.
12. Gradually enable production traffic with rollback and kill switches.

The kill switch must stop new ad requests and new cycles without deleting pending financial/audit records.

## Observability

Add structured logs and metrics without raw personal identifiers:

- heartbeats accepted/rejected by reason;
- valid-view transitions and dedup rejections;
- thresholds selected and reached;
- ad load success/failure/latency by platform and ad unit;
- pending/watched/bounced/expired impressions;
- callback duplication and late callbacks;
- attributed view and creator counts;
- allocated pending USD;
- reconciliation ratios and adjustments;
- USD reserve and USD/NGN available totals, never summed without an explicit conversion rate;
- FX quote source/age, conversion success/failure, rounding, spread/fee, and clearing-account differences;
- fraud blocks;
- job failures/dead letters;
- API latency/error rates.

Alert on:

- sudden impression or valid-view spikes;
- watched callbacks materially diverging from AdMob estimates;
- payouts created without a watched impression;
- watched impressions without exactly balanced allocations;
- stale pending impressions beyond TTL;
- allocations older than the hold with no settlement coverage;
- ledger imbalance;
- stale FX quotes, duplicate conversions, or non-zero USD/NGN FX-clearing balances outside the allowed settlement window;
- production use of test IDs or non-production use of live IDs.

## Test plan

### Laravel unit/feature tests

- 29.999 seconds is invalid for a long reel; 30.000 seconds is valid.
- Short reels qualify only at verified completion.
- Muted, paused, backgrounded, stale, replayed, and out-of-order heartbeats add no time.
- Server accumulation does not trust a client-provided total.
- Rolling 24-hour duplicate checks work immediately before/at/after the boundary and across sessions/app restarts.
- Concurrent requests cannot create two valid views.
- Raw scrolls never increment the ad cycle.
- Threshold generation includes 5 and 8 and never leaves the range.
- Atomic Redis processing creates one impression/attribution snapshot.
- Snapshot contains the correct distinct valid views and creator ownership.
- Redis retry/eviction cannot duplicate allocation.
- Impression confirmation is owner/session/platform bound and idempotent.
- Loaded-only, failed, skipped, expired, and bounced ads create no money.
- A watched impression allocates exactly USD 0.0002 in total.
- Two-to-one creator contribution produces a two-thirds/one-third split with deterministic rounding.
- Pending funds are visible but not payout eligible.
- No release occurs solely because 30 days elapsed.
- Approved finalized settlement scales down correctly and never releases more than collected.
- The 5% default reserve and changed future reserve rates are correct.
- A creator selecting USD receives the releasable amount only in the USD available ledger.
- A creator selecting NGN keeps pending/confirmed/reserve in USD and receives the releasable amount only in the NGN available ledger after one approved release-time conversion.
- USD-to-NGN conversion uses the snapshotted approved quote, deterministic kobo rounding, linked currency-balanced transactions, and an idempotent conversion record.
- A duplicate/retried release cannot convert the same USD amount twice.
- Stale, missing, unapproved, or client-supplied FX rates block conversion and payout without losing the confirmed USD amount.
- Changing payout currency affects future releases and does not mutate or convert existing USD/NGN balances.
- USD payout batches cannot select NGN funds, and NGN payout batches cannot select USD funds.
- Both USD and NGN ledger/FX clearing accounts reconcile independently.
- Reversals and late clawbacks remain balanced and immutable.
- Duplicate settlement imports/approvals are rejected.
- Fraud/sanction review blocks release.
- Legacy PCN reel accrual does not run after cutover.
- OpenAPI and authorization tests cover every new endpoint/action.

### Flutter unit/widget tests

- Heartbeats run only for active, playing, audible, foreground reels.
- Lifecycle, mute, pause, tab/feed changes, and disposal stop heartbeats.
- Reel/ad typed feed ordering is correct.
- Only a server `ad_due` instruction inserts a slot.
- `onAdLoaded` creates no watched request.
- `onAdImpression` sends exactly one idempotent watched request.
- Load failure and quick swipe create no payout path.
- Native ad disposal is correct.
- Reel playback pauses on the ad page.
- Creator Studio labels USD and NGN states accurately, keeps them separate from PCN, and makes currency preference changes future-only.
- Fake ad service prevents network/SDK calls in tests.

### Android manual/integration tests

- Google test native ad renders as full-screen 9:16.
- Ad attribution and AdChoices are visible.
- TalkBack traversal and touch targets are correct.
- Consent required/not-required/error and privacy-options paths work.
- Background, force-close, process recreation, offline, slow network, and rapid swipe cases create no false payout.
- Test-device logs show no policy/layout errors.

### iOS manual/integration tests

- Google test native ad renders with explicit constraints on supported devices.
- Ad attribution and AdChoices are visible.
- VoiceOver, Dynamic Type, and safe areas are correct.
- UMP then ATT sequencing works; denial still allows permitted ads.
- Background, force-close, memory pressure, offline, slow network, and rapid swipe cases create no false payout.
- Test-device logs show no policy/layout errors.

### Finance end-to-end test

With test/fake AdMob data:

1. Produce valid views from multiple creators.
2. Reach a deterministic test threshold.
3. Confirm no credit on load.
4. Fire one impression callback.
5. Verify proportional pending USD entries.
6. Verify bounce path produces zero entries.
7. Advance the clock 30 days and verify no release without settlement.
8. Import and approve a lower finalized total.
9. Release one creator to USD and another to NGN using a fixed approved test quote.
10. Verify proportional adjustments, 5% USD reserve, exact USD/NGN available amounts, conversion audit data, and currency-specific payout eligibility.
11. Change a creator's payout currency and verify only a future release uses the new currency.
12. Post a later clawback and verify append-only reserve/available/FX adjustments.

## Acceptance criteria

- Android and iOS production builds initialize consent and Native Advanced ads without crashes.
- Reels show only inline 9:16 Native Advanced ads, at a server-randomized 5–8 valid-view cadence.
- A valid view follows the 30-second/full-short-reel and rolling 24-hour rules using server-counted heartbeats.
- Every payable creator ledger entry traces to one watched impression and immutable attribution rows.
- No loaded, failed, skipped, bounced, expired, duplicated, or spoofed callback creates duplicate/payable funds.
- The USD 0.0002 pool is split exactly and proportionally by eligible view count.
- Credits appear pending immediately but cannot enter payout before hold, approved settlement reconciliation, and reserve deduction.
- Reconciled earnings remain in USD through reserve calculation; at release, creators receive either USD available funds or audited NGN available funds according to their effective preference.
- USD and NGN ledgers balance independently, every conversion is reproducible from its immutable FX record, and no payout batch mixes currencies.
- Changing payout currency never silently converts an existing available balance.
- Finalized monthly amounts come from the audited admin import; estimated API data is never called finalized.
- The default 5% reserve is configurable and all changes/true-ups are audited.
- Current immediate PCN reel-view accrual is disabled at cutover, with no double pay.
- Creator Studio, admin finance, legal disclosures, privacy controls, metrics, alerts, runbooks, and rollback controls are complete.
- Automated suites pass, and physical-device Android/iOS test checklists are signed off using test ads before any live ad unit is enabled.

## Definition of done

- Code, migrations, native factories, API contract, tests, configuration examples, and operational runbooks are merged.
- Database migration and rollback are exercised on production-like data.
- Horizon/scheduler workers for all new jobs are deployed and observed.
- AdMob apps, native ad units, test devices, consent messages, mediation, and reporting access are configured for both platforms.
- Finance has completed a dry-run finalized settlement import and approval.
- Finance has completed dry-run USD and NGN releases, FX-clearing reconciliation, and currency-specific payout batches.
- Legal/product has approved final Terms, Privacy, ATT, and consent copy.
- Google Play Data Safety and Apple App Privacy declarations are updated.
- Security/fraud review and mobile accessibility review are complete.
- Feature remains off by default until all launch gates are signed off.
