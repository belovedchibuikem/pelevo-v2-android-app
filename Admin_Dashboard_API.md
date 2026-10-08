# Pelevo Admin Dashboard & Production API

This document is the server-side contract for taking Pelevo from the current Flutter UI catalog to a production product. It is written against the screens, money rules, and domain objects that already exist in `pelevo-v2` — not a generic podcast CMS.

Companion file: [`Flutter_Implementation.md`](./Flutter_Implementation.md).

**Audit:** last checked against `lib/` on 7 Sep 2026. Every feature folder, catalog board, and singleton service is accounted for in §16.

---

## 1. What is already true

The mobile app is a **screen-state catalog**. Routing is `/screen/:id` via `go_router`. Persistence today is `SharedPreferences` / Hive. Networking is prepared (`dio` in `lib/core/services/app_services.dart`) but unused. Business rules already encoded in Dart must become **server-authoritative**:

| Rule (today in Flutter) | Source of truth in production |
|---|---|
| Podcast claim is a local boolean `podcast_creator_claimed` | Claim workflow + admin review |
| Reel create/publish is creator-gated | `GET /me` + claim status |
| Earn: 1 / 2 / 3 coins by duration bands (`<10m`, `<20m`, else) | Server award after verified listen |
| Earn lock: 72 hours per episode | Server lock window |
| Withdrawal floor: **1,250 coins = $5.00 USD** | Ledger + payout service |
| Display FX: **1 coin ≈ ₦4** (demo) | Configurable FX; never trust the client |
| Gift IAP product IDs `pelevo_coins_*` | Store + server receipt verify |
| Gift catalog: Applause 100, Love 500, Star 1,000, Champion 5,000 | Admin-managed catalog |
| Reels monetization: **100 followers + 1,000 views**, then opt-in | Eligibility job + admin override |
| Reels auto-payout: **monthly 1st–5th**, min **₦5,000** | Payout batcher |
| Comments: 400 chars, 15-minute edit, pin one top-level, hide, report | Comment service + moderation queue |
| Reels max duration **60 seconds** | Upload policy |
| Premium: Pelevo Plus monthly/yearly via Paystack / Flutterwave | Billing + entitlements |
| Device pairing: QR / code, conflict merge, backup | Device session + sync API |
| Invite: code `PELEVO-…`, both sides earn bonus coins after friend listens | Referral ledger + fraud rules |
| Follows are people **and** shows (`profile-following`, `search-people`) | `follows` polymorphic |
| Library has playlists **and** user collections, likes, saves, history | First-class library entities — not one filter param |
| Home includes **Live Now**; studio has `creator-go-live` | Live sessions + `lock-live-alert` |
| Gifts include an optional message (`GiftComposerSheet`) | Persist on `gifts.message` |
| Reels: like, bookmark, “see fewer”, episode link, For You / Following / Trending | Engagement + negative-signal APIs |
| Offline mode + data saver + audio quality Low→Very High | User prefs + download/stream policy |
| Sleep timer: Off / 15 / 30 / 60 / end of episode | Client-local; optional sync |
| Cast to speaker (`player-device`) | Client-local (Cast SDK); no money API |

If the Flutter demo and the API disagree, **the API wins**. The app must be rewritten to consume this contract.

---

## 2. Product shape (so the API does not drift)

Pelevo is three products sharing one identity:

1. **Listener** — discover (including Live Now and shorts), play (full + miniplayer), queue, download, library (playlists, collections, likes, saves), comments, gifts, earn-by-listening, Premium, AI Hub, stats, share cards, multi-device sync.
2. **Creator** — claim a show, multi-studio, episodes, reels, go-live, audience/supporters, gifts received, reels ads/tips, tax + payout currency/schedule.
3. **Operator** — catalog, claims, money, live sessions, moderation, referrals, support tickets, FX, feature flags.

Primary mobile IA (do not invent extra tabs):

`Home` · `Search` · `Library` · `Earn` · `Reels`

Profile, Creator Studio, Premium, AI Hub, Settings, Device Sync sit **off-tab**.

Market posture in the UI is **Nigeria-first, globally aware**: NUBAN + Paystack, Flutterwave across Africa, PayPal in USD, Apple/Google IAP for gift coins.

---

## 3. Recommended production stack

The Flutter client only cares about HTTPS + JSON. Recommended because this workspace already sits on WAMP and the money rails are African:

| Layer | Recommendation | Why |
|---|---|---|
| API | **Laravel 11+** (PHP 8.3), Sanctum/Passport or JWT | Fits WAMP, queues, jobs, policies, admin scaffolding |
| Admin UI | **Laravel + Inertia (React/Vue)** or Filament 3 | Fast RBAC, tables, audit, money screens |
| Primary DB | **MySQL 8** | Transactions for ledgers |
| Cache / sessions | **Redis** | Rate limits, feed cache, device presence |
| Search | **Meilisearch** or OpenSearch | Search / browse / people / playlists |
| Object storage | **S3-compatible** (Cloudflare R2 / AWS) | Covers, audio, reel video, share cards |
| Transcode | FFmpeg worker queue | HLS audio, reel MP4/HLS, thumbnails |
| Push | FCM + APNs | Notifications + lock-screen alerts |
| Email / SMS | SES or Resend + Termii / Twilio | Verify phone, claim codes, payout alerts |
| Payments | Paystack, Flutterwave, PayPal Payouts, Apple/Google IAP | Already in the UI |
| Observability | Sentry + structured logs + audit table | Money and moderation require a paper trail |

Version the public API as `/api/v1`. Never serve admin mutations on the same unscoped routes as the mobile app.

---

## 4. Cross-cutting API conventions

### 4.1 Envelope

```json
{
  "ok": true,
  "data": {},
  "meta": { "page": 1, "per_page": 20, "total": 0 },
  "error": null
}
```

Error:

```json
{
  "ok": false,
  "data": null,
  "error": {
    "code": "WITHDRAWAL_BELOW_THRESHOLD",
    "message": "Minimum withdrawal is 1250 coins.",
    "fields": {}
  }
}
```

Stable error codes the Flutter client will switch on (do not change casually):

`UNAUTHENTICATED` · `FORBIDDEN` · `VALIDATION` · `NOT_FOUND` · `CLAIM_REQUIRED` · `CLAIM_PENDING` · `EPISODE_LOCKED` · `INSUFFICIENT_COINS` · `WITHDRAWAL_BELOW_THRESHOLD` · `PAYOUT_METHOD_UNVERIFIED` · `IAP_UNVERIFIED` · `MONETIZATION_INELIGIBLE` · `UPLOAD_TOO_LONG` · `RATE_LIMITED` · `CONFLICT` · `MODERATION_HOLD`

### 4.2 Auth

- `POST /api/v1/auth/register` — email/username + password + phone
- `POST /api/v1/auth/login`
- `POST /api/v1/auth/social` — Google / Apple / Facebook token exchange
- `POST /api/v1/auth/otp/send` + `POST /api/v1/auth/otp/verify` — maps `auth-verify-number`
- `POST /api/v1/auth/password/forgot` + `reset` — maps `auth-forgot-password` / `auth-check-email`
- `POST /api/v1/auth/refresh` · `POST /api/v1/auth/logout`
- Bearer access token (short) + rotating refresh token
- Device id required on login (`X-Device-Id`) for session list / sign-out-all

Admin users are a **separate guard** (`admins` table, not `users.is_admin` alone). Admin sessions use cookie + 2FA.

### 4.3 Idempotency

Every money-mutating request (`gifts.send`, `withdrawals.store`, IAP verify, earn complete) must send `Idempotency-Key`. Replay returns the original result.

### 4.4 Pagination & localization

Cursor pagination for feeds and comments. Offset is acceptable for admin tables.

`Accept-Language` and user `locale` / `dialect` from onboarding (`onboarding-language`, `onboarding-interests`) drive catalog ranking.

---

## 5. Canonical domain model

These tables are the minimum honest schema. Names can vary; relationships should not.

### Identity

- `users` — profile, handle, phone, email, locale, interests[], role flags
- `user_preferences` — email prefs, AI settings, audio quality, quiet hours
- `connected_accounts` — Google / Apple / Facebook / PayPal identity
- `devices` — name, platform, trusted, last_sync_at, pairing
- `device_pairings` — QR / 6-digit code, expires_at
- `sync_cursors` / `sync_conflicts`

### Catalog

- `shows` — title, slug, description, category, language, cover, rss_url, claim_status, rating aggregates
- `episodes` — show_id, title, description, audio_key, duration, published_at, chapters[], transcript_status, plus_only
- `playlists` — user or editorial (`library-2/3`, `home-playlists`)
- `playlist_items`
- `collections` — user-named groups distinct from playlists (`library-9` create/details)
- `collection_items` — episodes and/or shows
- `categories` / `tags` (home “Browse Categories”, `browse-music`, earn niches)
- `reviews` — show-level (maps `podcast-reviews`)
- `follows` — polymorphic: user→show **or** user→user (`profile-following`, `search-people`)
- `episode_saves` / `episode_likes` (`library-4`, `library-7`)
- `reel_likes` / `reel_saves` / `reel_not_interested`
- `library_items` — in-progress + followed-shows shelf (`library-6`, `library-8`)
- `episode_notes` — private listener notes (`episode-notes`, `player-transcript` catalog id = notes)
- `playback_progress` — episode_id, position_ms, completed, device_id
- `queues` / `queue_items` — play-next, shuffle flag, history
- `listening_stats` daily rollups + `achievements` / `streaks` (`stats-*`)
- `live_sessions` — also listed under creator; home **Live Now** reads public live rows
- `referrals` — inviter, code, invitee, status, bonus_coins (`profile-invite`)
- `support_tickets` / `feedback` (`profile-help`)

### Reels

- `reels` — creator_id, video_key, caption, tag (`Mindset` etc.), duration, status (`draft|processing|published|rejected|removed`)
- `reel_episode_links` — reel_id → episode_id (already modeled in `ReelEpisodeLinkService`)
- `reel_drafts` — optional server drafts; client may keep local until publish
- `reel_metrics` — views, likes, comments, shares, bookmarks (materialized)

### Social

- `comments` — target_type `episode|reel`, target_id, parent_id, body, pinned, hidden, like_count; optional `@mention` tokens
- `comment_likes`
- `reports` — target comment/reel/user, reason, status
- `notifications` typed: `new_episode`, `download_complete`, `daily_reminder`, `mention`, `follow`, `digest`, `promotion`, `live`, `playlist_updated`, `recommendation`, `episode_expiring`
- `notification_preferences` + lock-screen rules (style, quiet hours, DND, snooze, custom rules, widget, focus)
- `share_cards` — template, quote, QR, branding, background, scheduled_at, analytics, export artifacts

### Money (four ledgers, never one pile)

Keep **separate balances**. The UI already treats them as different products.

1. **`gift_wallets`** — IAP-purchased coins, spend only on gifts  
2. **`earn_wallets`** — listen-to-earn coins, withdrawable after threshold  
3. **`creator_balances`** — gifts received (after platform fee) + reels ads/tips/bonus, payout in NGN/USD  
4. **`premium_entitlements`** — subscription state, not a coin wallet

Supporting:

- `ledger_entries` — immutable: `{wallet_type, user_id, amount, currency, ref_type, ref_id, idempotency_key}`
- `coin_packs` — `pelevo_coins_500` … `pelevo_coins_15000` + store SKUs
- `gift_types` — Applause / Love / Star / Champion + coin cost + creator credit
- `gifts` — from_user, to_creator, content_type, content_id, gift_type_id, optional `message`
- `iap_receipts` — store, product_id, transaction_id, verified_at
- `earn_awards` — episode_id, coins, locked_until
- `payout_methods` — gateway `paystack|paypal|flutterwave`, destination, verified
- `withdrawals` — earn-wallet cashout (listener)
- `creator_payouts` — monthly auto + manual
- `fx_rates` — coin↔USD↔NGN; admin editable, versioned
- `subscriptions` / `invoices` — Pelevo Plus

### Creator ops

- `studios` — a creator may own multiple shows (maps `creator-studios`, `creator-add-studio`)
- `show_claims` — method `rss|manual_code`, code, status `pending|approved|rejected`
- `live_sessions` — `creator-go-live`
- `tax_profiles` — `creator-tax-information`

### AI

- `ai_jobs` — type `recommend|summary|chapters|highlights|ask`, status, result JSON
- Rate-limit and cost-cap per user / Premium tier

### Admin

- `admins` + `roles` + `permissions`
- `audit_logs` — who, action, before/after, ip
- `feature_flags`
- `cms_pages` — About, Help/FAQ, guidelines (`share-card-guidelines`, `profile-about`, `profile-help`)
- `home_rails` — admin-ordered rails: continue, top_picks, because_you_listened, trending_shows, suggested_episodes, trending_shorts, suggested_shorts, categories, new_episodes, charts, playlists, live_now

---

## 6. Mobile API surface (mapped to Flutter screens)

Base: `https://api.pelevo.tld/api/v1`

### Auth & onboarding

| Method | Path | Flutter screens |
|---|---|---|
| POST | `/auth/*` | `auth-sign-in`, `auth-create-account`, `auth-account-created`, `auth-options`, `auth-verify-number`, `auth-forgot-password`, `auth-check-email` |
| PUT | `/me/onboarding` | `onboarding-interests`, language, community/AI opt-in |
| GET/PATCH | `/me` | `profile`, `profile-edit` (name, handle, bio, avatar), `profile-personal` |
| PATCH | `/me/password` | settings “Change Password” (or reuse forgot flow) |
| PATCH | `/me/preferences` | `profile-email`, audio quality Low/Normal/High/Very High, data saver, offline mode, dark mode (client-only today), AI settings |
| GET/POST | `/me/connected-accounts` | `profile-connected` |
| GET | `/me/following` | `profile-following` — mixed shows + people |
| POST | `/me/invite` · `GET /me/invite` | `profile-invite` — code + share link |
| POST | `/me/delete` | NDPR account deletion from `settings-account` |
| GET | `/cms/help` · `POST /support/tickets` · `POST /support/feedback` | `profile-help` |
| GET | `/cms/about` | `profile-about` |

### Home, search, browse, catalog

| Method | Path | Flutter screens |
|---|---|---|
| GET | `/home/feed` | `home-feed` rails: Continue Listening, Top Picks, Because You Listened, Trending Podcasts, Episodes You Might Like, Trending Shorts, Shorts You Might Like, Browse Categories, New Episodes |
| GET | `/home/discover` | `home-discover` — Trending Now + more |
| GET | `/home/charts` | `home-charts` — ranked by region/category |
| GET | `/home/playlists` | `home-playlists` — user + editorial + Shorts shortcuts |
| GET | `/live` | Home **Live Now** + discover live |
| GET | `/search?q=&type=show\|episode\|person\|playlist\|reel` | `search`, `search-typing`, `search-results`, `search-people`, `search-playlists`, `search-empty`, `search-filters` |
| GET/POST | `/search/recent` | `search-recent` |
| POST | `/search/voice` | `search-voice`, `search-voice-results` (Whisper or equivalent) |
| GET | `/browse` · `/browse/categories` · `/browse/{slug}` | `browse`, `browse-categories`, `browse-music`, `browse-detail`, `browse-new`, `browse-preview`, `browse-following`, `browse-search`, `browse-filters`, `browse-added` |
| GET | `/shows/{id}` | `podcast-details`, `podcast-about`, `podcast-unavailable` |
| GET | `/shows/{id}/episodes` | `podcast-episodes` |
| POST | `/shows/{id}/follow` | `podcast-following`, `podcast-unfollowed` |
| PATCH | `/shows/{id}/notifications` | `podcast-notifications` |
| GET/POST | `/shows/{id}/reviews` | `podcast-reviews` |
| GET | `/shows/{id}/related` | `podcast-related` |
| GET | `/episodes/{id}` | `episode-details`, `episode-description`, `episode-unavailable` |
| GET | `/episodes/{id}/chapters` | `episode-chapters` |
| GET | `/episodes/{id}/transcript` | `episode-transcript`, `episode-transcript-search` |
| GET/PUT | `/episodes/{id}/notes` | `episode-notes` (private) |
| POST | `/episodes/{id}/like` · `/save` · `/queue` · `/download` | `episode-share`, `episode-queued`, `episode-download`, `episode-playing` |
| POST | `/users/{id}/follow` | people follow from search/profile |

### Playback, queue, downloads, library, stats

Progress is **authoritative on the server**, last-write-wins with device vector clocks. Earn playback **must not** share this progress store (the Flutter code already isolates `EarnPlaybackSession`).

| Method | Path | Flutter screens |
|---|---|---|
| PUT | `/playback/{episodeId}` | progress for full player + miniplayer (`player-now-playing`, `player-paused` / mini-search, `player-buffering` / mini-discover) |
| GET/PATCH | `/player/session` | speed, skip amounts; **sleep timer and Cast stay client-local** unless you later sync sleep |
| GET/PUT | `/queue` | up-next, play-next (`queue-autoplay`), reorder, multi-select remove, clear, shuffle (`queue-smart`), history (`queue-history`), auto-download (`queue-downloads`) |
| GET | `/library` | home overview `library-1` |
| GET/POST/PATCH | `/playlists` · `/playlists/{id}` | `library-2`, `library-3` |
| GET/POST/PATCH | `/collections` · `/collections/{id}` | `library-9` … `library-11` |
| GET | `/library/saved` · `/liked` · `/shows` · `/recent` | `library-4`, `library-7`, `library-6`, `library-8` |
| GET/PATCH | `/library/settings` | `library-12` |
| GET | `/downloads` · `POST /downloads/authorize` · `PATCH /downloads/settings` | `library-5` + `downloads-1`…`12`: queue, smart downloads, quality, 5 GB cap, location, bulk delete, history, offline mode |
| GET | `/stats/me` | overview, time, completion, top shows, heatmap, streaks, genres, monthly, **achievements**, download stats, device split, period compare (`stats-share`) |

Do **not** collapse Library into `?filter=` only. Playlists and collections are writable resources. Showcase ids `library-1`…`12` are **twelve views** of that cluster.

### Comments & reports

| Method | Path | Notes |
|---|---|---|
| GET | `/comments?target_type=&target_id=&sort=newest\|top\|creator` | `episode-comments`, `reel-comments`, empty state |
| POST | `/comments` | max 400; parent_id for replies |
| PATCH | `/comments/{id}` | only author, 15 minutes |
| DELETE | `/comments/{id}` | author or creator-of-target or admin |
| POST | `/comments/{id}/like` | toggle |
| POST | `/comments/{id}/pin` | creator of target, one pin |
| POST | `/comments/{id}/hide` | creator moderation |
| POST | `/reports` | `comment-report` |

### Reels

| Method | Path | Flutter screens |
|---|---|---|
| GET | `/reels/for-you` · `/reels/following` · `/reels/trending` | `reels` |
| GET | `/reels/{id}` | individual reel cards |
| POST | `/reels/uploads` | initiate multipart / direct-to-S3 |
| POST | `/reels` | publish after processing (`reels-editor`) |
| GET/PUT/DELETE | `/reels/drafts` | `reels-drafts` |
| PUT | `/reels/{id}/episode-link` | `ReelEpisodeLinkService` |
| POST | `/reels/{id}/view` | idempotent view ping (dedupe) |
| POST | `/reels/{id}/like` · `/save` · `/not-interested` | heart, bookmark, “See fewer reels like this” |
| GET | `/reels/{id}/related-show` | “Open related podcast” |
| GET | `/reels/monetization` | progress / eligible / active |
| POST | `/reels/monetization/opt-in` | requires 100 followers + 1,000 views |

Create/record/upload endpoints return `CLAIM_REQUIRED` if the user has not claimed a show — matching `_creatorOnlyReelScreens` in `lib/app.dart`.

### Gifts & IAP

| Method | Path | Flutter screens |
|---|---|---|
| GET | `/gifts/catalog` | `GiftComposerSheet` on episode/reel |
| GET | `/gifts/wallet` | `gift-wallet`, ledger / `gift-receipt` |
| GET | `/gifts/packs` | `gift-coin-store` |
| POST | `/iap/verify` | `gift-purchase-success` / `failed` — **never credit from the client** |
| POST | `/gifts/send` | body: gift_type, target, optional message; then `gift-receipt` |

Coin packs must match store SKUs:

`pelevo_coins_500` · `pelevo_coins_1200` · `pelevo_coins_2500` · `pelevo_coins_6500` · `pelevo_coins_15000`

Verifier hook already exists in Flutter as `GiftPurchaseVerifier`. Production implementation: send the store receipt to `/iap/verify`, wait for `ok`, then refresh wallet.

### Earn (listen-to-earn)

Isolated from the normal player. Anti-fraud is mandatory or this product will be farmed.

| Method | Path | Flutter screens |
|---|---|---|
| GET | `/earn/shows` · `/earn/episodes` | `earn`, `earn-all` |
| POST | `/earn/sessions` | start (`earn-player`) |
| POST | `/earn/sessions/{id}/heartbeat` | every 15–30s with position + integrity token |
| POST | `/earn/sessions/{id}/complete` | awards coins, sets 72h lock |
| GET | `/earn/wallet` | `earn-wallet` |
| GET/POST | `/payout-methods` | `withdraw-setup-paystack\|paypal\|flutterwave` |
| POST | `/withdrawals` | `withdraw-amount` → `withdraw-review` → `withdraw-success` |
| GET | `/withdrawals` | `withdraw-history` |

**Award table (keep unless product changes it in admin):**

| Episode duration | Coins |
|---|---|
| < 10 minutes | 1 |
| < 20 minutes | 2 |
| ≥ 20 minutes | 3 |

**Fraud controls (admin-visible):**

- Heartbeats must be monotonic and roughly realtime
- Max N completions / user / day
- Device + IP velocity
- Same-audio fingerprint reuse
- Lock 72h per user per episode (not per device)
- Completions under review do not credit until cleared

**Payout:**

- Minimum **1,250 earn coins**
- Status machine: `queued` → `processing` (1st–5th window) → `paid` | `failed` | `rejected`
- Paystack: verify NUBAN via Paystack Resolution API before `verified=true`
- PayPal: email confirmed twice, payout in USD
- Flutterwave: bank or mobile wallet

### Creator studio

| Method | Path | Flutter screens |
|---|---|---|
| GET | `/shows/{id}` public + `claim_state` | `relationship-podcast` |
| POST | `/claims` | `claim-podcast`, `claim-method` |
| POST | `/claims/{id}/rss` | `claim-rss` |
| POST | `/claims/{id}/code` | `claim-enter-code`, `claim-manual-code` |
| GET | `/claims/{id}` | `claim-review`, `claim-success`, `claim-failed` |
| GET | `/studio` | `creator-studio`, `creator-dashboard` |
| GET/POST | `/studio/shows` | `creator-studios`, `creator-add-studio` |
| GET/POST/PATCH | `/studio/episodes` | `creator-episodes`, `creator-new-episode`, `creator-episode-details` |
| GET | `/studio/reels` | `creator-reels`, `creator-reel-details` |
| GET | `/studio/audience` | `creator-audience`, followers, supporters |
| GET | `/studio/monetization` | `creator-monetization` |
| GET | `/studio/transactions/{id}` | `creator-transactions`, `creator-transaction-details` |
| GET/PUT | `/studio/payout-settings` | `creator-payout-settings`, `creator-add-payout`, `creator-payout-schedule`, `creator-payout-currency`, `creator-tax-information` |
| POST | `/studio/live` · `PATCH /studio/live/{id}` | `creator-go-live` — ingest URL / status; fans see `/live` |

RSS claim: API generates a token; creator places it in the feed `<podcast:guid>` / description; worker polls RSS; on match, `approved` or send to admin if confidence is low.

### Premium

| Method | Path | Flutter screens |
|---|---|---|
| GET | `/premium/plans` | `premium-intro`, `premium-plans`, `premium-compare` |
| POST | `/premium/checkout` | `premium-payment` (Paystack/Flutterwave initialize) |
| GET | `/premium/me` | `premium-subscription`, `premium-features` |
| POST | `/premium/change-plan` | `premium-change-plan` |
| GET | `/premium/invoices` | `premium-billing` |
| POST | `/premium/restore` | `premium-restore` |
| GET | `/premium/exclusive` | `premium-exclusive` |

Webhooks: `/webhooks/paystack`, `/webhooks/flutterwave`, `/webhooks/paypal` — signature verified, then entitlement + invoice rows. Never trust a client “payment successful” screen.

### Notifications, lock screen, devices, share cards, AI

| Method | Path | Flutter screens |
|---|---|---|
| GET/PATCH | `/notifications` | inbox, filters, mark-read, clear-all, history (`notifications-1`…`12`) |
| GET/PUT | `/notifications/preferences` | new episodes, recommendations, mentions, promotions, digest |
| GET/PUT | `/notifications/lock-rules` | `lock-new-episode` … `lock-about`: style, controls, privacy, quiet hours, sound, DND, snooze, custom rules, widget, focus, analytics |
| GET/POST | `/devices` · `/devices/pair` (QR + code) · `/devices/{id}` | `device-sync-basic-*` **and** expanded `device-*` / `sync-*` / `connected-devices` |
| POST | `/devices/sign-out-all` | `sign-out-all-devices` |
| POST | `/sync/push` · `GET /sync/pull` | scopes: listening, library, downloads, playlists, bookmarks, favorites, history, recent plays |
| POST | `/sync/conflicts/{id}/resolve` | `conflict-*`, `merge-progress` |
| POST | `/backups` · `POST /backups/{id}/restore` | `backup-*`, `cloud-backup-settings` |
| GET | `/storage` · `POST /storage/clear-cache` | `storage-*`, `clear-cache`, `reset-sync-data` |
| GET | `/devices/activity` · `/devices/trusted` | `device-activity-log`, `trusted-devices`, `encryption-security`, `device-limit` |
| POST | `/share-cards` | wizard: content → template → customize → preview → share/QR/quote |
| GET | `/share-cards` · `GET /share-cards/{id}/analytics` | my cards, saved, scheduled, top, analytics, export, download, guidelines |
| POST | `/ai/jobs` · `GET /ai/jobs/{id}` | hub, recommender, summary, chapters, highlights, ask, settings |
| PATCH | `/referrals/redeem` | invitee applies code at register |

---

## 7. Admin dashboard information architecture

Build the dashboard as an **operations console**, not a second Pelevo app. Suggested modules:

### 7.1 Command center

- DAU / WAU, new accounts, listen hours
- Earn coins issued vs withdrawn (liability)
- Gift coins purchased vs gifted vs creator credit
- Reels uploaded / rejected
- Open claims, open reports, payouts in the monthly window
- Live sessions currently on air
- Referral conversions / bonus coins issued
- Open support tickets
- Webhook health (Paystack / Flutterwave / stores)

### 7.2 Users

- Search by email, handle, phone, device
- Force logout, disable, shadow-ban
- Wallet inspector (all four money surfaces)
- Device list + sign-out-all
- Connected accounts

Roles: `superadmin`, `support`, `moderator`, `finance`, `catalog_editor`, `analyst`. Support can refund small gift/earn amounts; only finance can run payout batches.

### 7.3 Catalog

- Shows & episodes CRUD
- RSS ingest monitor
- Categories, charts, editorial playlists, home-rail editor (`home_rails`)
- “Earn-eligible” flag, Plus-only flag (`premium-exclusive`)
- Artwork and audio replace with re-transcode
- Live session monitor (start/stop/takedown)

### 7.4 Claims queue

States: `pending_rss` · `pending_manual` · `needs_review` · `approved` · `rejected`.

Actions: approve, reject with reason, request new code, merge duplicate shows. This replaces the Flutter local `PodcastCreatorService.claim()`.

### 7.5 Reels moderation

- Pre-publish automatic checks (duration ≤ 60s, malware, blank frames)
- Queue: new, reported, appealed
- Actions: publish, reject, remove, strike creator
- Episode-link integrity (broken episode → unlink)

### 7.6 Comments & reports

- Filter by target, reason, creator
- Hide / restore / delete / ban
- SLA timer for reports

### 7.7 Finance

This is the most important admin surface. Split it:

1. **FX & products** — coin packs, gift types, earn award table, withdrawal minimums, reels eligibility thresholds, platform fee %  
2. **IAP** — unmatched receipts, verify failures (`gift-purchase-failed`)  
3. **Earn liability** — coins outstanding, daily issuance, suspected farms  
4. **Listener withdrawals** — queue for 1st–5th, mark paid/failed, retry gateway  
5. **Creator payouts** — monthly auto-payout ≥ ₦5,000, hold, split tax  
6. **Premium** — MRR, churn, failed charges, refunds  
7. **Ledger explorer** — every credit/debit immutable

Never edit a ledger row. Corrections are reversing entries.

### 7.8 Notifications, live, referrals & CMS

- Broadcast / segment push (maps lock + in-app types including promotions and daily digest)
- Live takedown
- Referral program: bonus amounts, cap per user, farm detection
- Help center FAQ, About, community guidelines, support inbox (`profile-help`)
- Feature flags: `earn_enabled`, `gifts_enabled`, `reels_upload`, `ai_hub`, `premium`, `live`, `referrals`, `share_cards`

### 7.9 AI cost desk

- Tokens / job type
- Kill switch
- Prompt versions

### 7.10 Audit

Every admin write: actor, resource, diff, reason. Finance and ban actions require a reason field.

---

## 8. Admin API (separate prefix)

`/api/admin/v1` with permission middleware.

Examples:

- `GET /admin/v1/metrics/overview`
- `GET/POST /admin/v1/users` · `POST /admin/v1/users/{id}/disable`
- `GET /admin/v1/claims` · `POST /admin/v1/claims/{id}/approve`
- `GET /admin/v1/reels/queue` · `POST /admin/v1/reels/{id}/reject`
- `GET /admin/v1/reports`
- `GET /admin/v1/ledger` · `POST /admin/v1/ledger/adjust` (reversal)
- `POST /admin/v1/payouts/batch/run`
- `PUT /admin/v1/settings/fx`
- `PUT /admin/v1/settings/flags`
- `GET /admin/v1/audit`

Admin UI talks only to this prefix. Mobile tokens must 403 here.

---

## 9. Money architecture (non-negotiable)

```
IAP Store ──verify──► gift_wallets ──send gift──► creator_balances
Listen heartbeats ──complete──► earn_wallets ──withdraw──► Paystack/PayPal/Flutterwave
Reels ads/tips/bonus ──monthly──► creator_balances ──payout──► bank
Paystack/Flutterwave checkout ──webhook──► premium_entitlements
```

**Platform fee** (set in admin, default suggestion): 30% of gift coin value credited to creator in NGN at the dated FX rate. Listen-to-earn is a **user acquisition cost**, not a creator revenue share, unless product later says otherwise.

**Reels creator split** (from `ReelsMonetizationService` demo breakdown — make these admin fields):

- Ad revenue
- Bonus
- Tips (may overlap gifts; decide one pipe and document it)

**Concurrency:** wallet updates use `SELECT … FOR UPDATE` inside a DB transaction keyed by `idempotency_key`.

**Reconciliation job (daily):**

- Store settlement vs `iap_receipts`
- Gateway payouts vs `withdrawals` / `creator_payouts`
- Alert finance if drift > threshold

---

## 10. Media pipeline

1. Client requests `POST /uploads` `{purpose: reel|episode_audio|cover|share_card}`  
2. API returns presigned PUT + `upload_id`  
3. Client uploads to object storage  
4. Client `POST /uploads/{id}/complete`  
5. Worker: probe duration, reject reels > 60s, generate poster, HLS, waveform  
6. Status webhook / poll: `processing` → `ready` | `failed`

CDN in front. Signed playback URLs for Plus-only and earn-anti-hotlink.

---

## 11. Security, compliance, production hygiene

- TLS only; HSTS; admin on a separate subdomain (`admin.pelevo.tld`)
- 2FA for all admins; finance role on hardware key if possible
- Rate limits: auth, search, comments, earn heartbeats, gift send
- PII: phone, NUBAN, PayPal email encrypted at rest
- NDPR / data-export / delete-account (`settings-account`)
- Webhook replay protection
- CORS locked to admin origin; mobile uses no cookies
- Secrets in env, never in the Flutter repo
- Staging that uses Paystack/Flutterwave **test keys** and store sandbox SKUs
- Load-test earn complete + gift send before public launch

---

## 12. Delivery phases (API + admin)

Do not build every screen’s endpoint in week one. Sequence by **liability and uniqueness**.

### Phase 0 — Foundation (1–2 sprints)

Auth, users, devices, feature flags, audit, envelope, admin RBAC, empty command center.

### Phase 1 — Catalog + playback

Shows, episodes, search, home rails, progress, library, queue, downloads authorize. Enough to replace hardcoded home/search/podcast/episode screens.

### Phase 2 — Identity of creators

Claim flow + admin queue + studio read APIs. Unblocks reel upload gating.

### Phase 3 — Social

Comments, likes, reports, notifications. Reels feed + publish (even if monetization is later).

### Phase 4 — Money (hardest)

Gift IAP verify + send. Earn sessions + locks + withdrawals. FX admin. Ledger explorer. **No public earn/gifts without this.**

### Phase 5 — Creator money + Premium

Reels eligibility job, monthly payouts, Premium checkout webhooks.

### Phase 6 — Sync, share cards, AI, lock-screen rules

These are large UX surfaces already designed; they are not launch-blockers for a private beta.

---

## 13. Acceptance tests the dashboard must make easy

Operators should be able to complete these without engineering:

1. Approve a podcast claim and see Creator Studio unlock on the next `/me`.
2. Reject a reel and have it disappear from For You.
3. Hide a comment and confirm listeners no longer see it; creator still can in studio.
4. Replay an IAP receipt and **not** double-credit.
5. Complete a valid earn listen and see +1/+2/+3 coins and a 72h lock.
6. Reject a farmed earn session and reverse the coins.
7. Run the monthly payout batch and export a CSV for finance.
8. Change FX and have **new** conversions use the new rate; old ledger rows stay frozen.
9. Disable `earn_enabled` and have the app hide the Earn tab (via `/me/config`).
10. Ban a user and invalidate all device refresh tokens.

---

## 14. `/me/config` — the app’s remote control

Ship this on day one so Flutter does not hardcode policy:

```json
{
  "tabs": ["home", "search", "library", "earn", "reels"],
  "flags": {
    "earn_enabled": true,
    "gifts_enabled": true,
    "reels_upload": true,
    "ai_hub": false,
    "premium": true,
    "live": true,
    "referrals": true,
    "share_cards": true
  },
  "money": {
    "earn_min_withdraw_coins": 1250,
    "earn_coin_usd": 0.004,
    "display_ngn_per_coin": 4,
    "earn_lock_hours": 72,
    "reels_min_followers": 100,
    "reels_min_views": 1000,
    "reels_min_payout_ngn": 5000,
    "gift_catalog_version": 3
  }
}
```

Admin edits this. Flutter caches it. Production behavior stays tunable without an app store release.

---

## 15. How to use this file

- Backend: treat §5–§8 as the backlog. Each table + route is a ticket.
- Admin: treat §7 + §13 as the UX spec.
- Flutter: implement only against §4, §6, and §14. See `Flutter_Implementation.md` for the client migration.
- Product: if a rule in §1 must change, change it here **and** in admin settings — do not silently change Dart constants.

---

## 16. Complete coverage matrix (app → API → admin)

If a row is missing from the API or admin, the product is not fully specified. Local-only means no server mutation is required for v1.

| App surface (`lib/features/…`) | Catalog / entry | API | Admin |
|---|---|---|---|
| `onboarding` | splash, 4 features, interests | `/me/onboarding` | flags |
| `authentication` | sign-in, register, verify, options, forgot, check-email, account-created | `/auth/*` | user search, force logout |
| `permissions` | intro → complete | none (OS); token for FCM after notify grant | — |
| `home` | feed, discover, charts, playlists, **Live Now**, shorts rails | `/home/*`, `/live` | home rail editor, live monitor |
| `search` | query, filters, people, playlists, empty, recent, voice | `/search`, `/search/voice` | search relevance |
| `browse` | categories, music, detail, new, preview, following, filters, added | `/browse/*` | categories |
| `podcast` | details, about, episodes, follow, unavailable, reviews, related, alerts, loading | `/shows/*` | catalog |
| `episode` | details, description, chapters, transcript + search, notes, download, queued, share, unavailable, sleep, playing | `/episodes/*`, notes, queue | catalog |
| `player` | full, mini over search/discover, sleep, speed, **cast**, chapters, notes, queue, share, download, more | `/playback`, `/player/session` | — ; Cast/sleep local |
| `queue` | up next, edit, reorder, empty, play-next, shuffle, auto-dl, history | `/queue` | — |
| `library` | home, playlists, playlist details, saved, downloads, shows, liked, recent, **collections** CRUD, settings | `/library`, `/playlists`, `/collections` | — |
| `downloads` | overview, active, smart, storage, bulk, location, offline, history | `/downloads*` | — |
| `notifications` | inbox, filters, types (episode, download, reminder, mentions, digest, promotions), settings, history | `/notifications*` | broadcasts |
| `lock_screen` | 8 alert types + settings/style/privacy/quiet/DND/snooze/rules/widget/focus/analytics | `/notifications/lock-rules` | push templates |
| `device_sync` (basic 12 + expanded) | pair QR/code, sync scopes, backup, conflicts, storage, trusted, limit, encryption, activity, sign-out-all | `/devices`, `/sync`, `/backups`, `/storage` | device inspector |
| `stats` | time, completion, top shows, heatmap, streaks, genres, monthly, **achievements**, downloads, devices, compare | `/stats/me` | optional achievement CMS |
| `ai` | hub, recommend, summary, chapters, highlights, ask, settings | `/ai/jobs` | AI cost desk |
| `comments` | episode/reel, empty, replies, report | `/comments`, `/reports` | moderation |
| `gifts` | store, wallet, IAP success/fail, composer + message, receipt | `/gifts/*`, `/iap/verify` | coin packs, ledger |
| `earn` | catalog, all, isolated player, wallet | `/earn/*` | liability, farms |
| `earn` withdrawals | Paystack/PayPal/Flutterwave setup, amount, review, success, history | `/payout-methods`, `/withdrawals` | payout batch |
| `reels` | For You / Following / Trending, like, bookmark, gift, comments, not-interested, episode link | `/reels/*` | reel queue |
| `reels` create | create, record, upload, drafts, editor (60s, claim-gated) | uploads + publish | duration policy |
| `reels` monetization | progressing / eligible / active, monthly auto-payout | `/reels/monetization` | thresholds, payouts |
| `creator` studio | relationship page, claim, studio, dashboard, studios, add studio | `/claims`, `/studio` | claims queue |
| `creator` content | episodes, episode details, reels, reel details, create reel | `/studio/episodes`, `/studio/reels` | — |
| `creator` audience | overview, followers, **supporters** (gifters), new episode, **go live** | `/studio/audience`, `/studio/live` | live takedown |
| `creator` money | monetization, txns, payout settings/add, **schedule**, **currency**, **tax** | `/studio/payout-settings` | finance |
| `premium` | intro, plans, compare, account, payment, confirmed, features, manage, change, billing, restore, exclusive | `/premium/*` + webhooks | MRR / invoices |
| `share_cards` | 21-state wizard (template, QR, quote, branding, schedule, analytics, export, guidelines) | `/share-cards*` | guidelines CMS |
| `profile` | stats, Plus card, studio/claim, earn wallet, history, following, sync, devices, offline, settings, help, **invite**, about, logout | `/me`, `/me/following` | users |
| `profile` support | edit, following, help FAQ + contact + feedback, invite rewards, about | `/cms/*`, `/support/*`, `/me/invite` | support inbox, referral desk |
| `showcase` | `/catalog` | none | none — debug only |

**Not a separate backend product:** sleep timer, Cast, dark-mode toggle (app is dark-only today), designer catalog.

**Phase note:** Live, referrals, share-card scheduling, AI, lock-widget, and achievements can ship after listen + money. They are still in the contract so they are not “forgotten features.”
