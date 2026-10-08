# Pelevo Flutter Implementation Guide

This is the client-side production plan for `pelevo-v2`. It assumes the API and admin contract in [`Admin_Dashboard_API.md`](./Admin_Dashboard_API.md).

**Audit:** last checked against `lib/` and the API on 10 Sep 2026. Splash, onboarding/auth confirmation, permissions, Home destinations/See All, the creator claim wizard, Creator Studio / Dashboard, creator episodes/details, creator reels/details, create-reel drafts, creator monetization/transactions/payouts, creator audience/followers/supporters, new-episode drafts, go-live, tax/currency/schedule, creator studios/add-studio, gift store/wallet/purchase/receipt, episode/reel comments plus comment report, listener reels feed/create/drafts/editor plus reels monetization states, earn catalog/withdrawals/invite, connected accounts, and search/browse catalog states are wired to existing layouts. §7.1 records the current Home experience. §17 lists every feature folder. §5 matches the real `_PlayerView` / `_LibraryView` enums.

The job is not to redraw the UI. The UI catalog is already the product. The job is to **replace demo state with a real client architecture** without throwing away the screens.

## 0. Sequential implementation tracker

### Batch 1 — Splash startup (implemented; device acceptance pending)

- Preserved the existing `SplashScreen` artwork and layout.
- A stored session is validated through `GET /me`; a rejected refresh routes to Sign In, while a temporary API outage retains the valid cached session.
- Authenticated startup prefetches and validates `GET /me/config` through the new `AppConfigController`.
- A malformed successful identity response is no longer accepted as authenticated startup state.
- First launch continues to the existing onboarding screens. Once the introduction is completed, subsequent signed-out launches go directly to the existing Sign In screen.
- The introduction-seen flag is persisted in `SharedPreferences`; tokens remain in secure storage.
- No Laravel endpoint was missing for this batch. Existing `/me`, `/me/config`, and auth refresh contracts cover startup.

### Batch 2 — Onboarding, remaining auth, permissions (implemented; device acceptance pending)

- Introduction slides are unchanged. Skip and Next still use the existing feature screens.
- `InterestsScreen` keeps its chips and language dropdown. Selections are saved as a local draft before Sign In.
- Authenticated submit uses `PUT /me/onboarding` with catalog interests and locale. API failure retains the draft and shows the existing inline error treatment so Get Started can retry.
- Login, registration, email-code sign-in, splash, and Account Created apply a pending draft without inventing a new screen. A mismatched owner response is not treated as success.
- `GET /me` now reports `onboarded` and `interests`. Locale is written only when the client sends one, so a profile row is not invented.
- Account Created still uses the existing welcome artwork and continues to Permissions. Social options remain unavailable and say so on the existing dialog.
- Permissions screens still request notifications and microphone on the matching Allow actions. Finish Setup, Go to App, and Maybe Later persist a local completion flag.
- Verification: `flutter analyze lib test` is clean. Focused Flutter tests covering startup, onboarding, catalog navigation and router guards passed (47). Laravel `MobileOnboardingTest`, `ProfileApiTest`, `IdentityLifecycleTest` and `OpenApiPhaseZeroContractTest` passed (28 tests, 232 assertions). Device and golden acceptance remain pending.

### Batch 3 — Home Discover, Charts, Playlists & More, See All (implemented; device acceptance pending)

- Existing Discover, Charts, Playlists and See All layouts are unchanged. Seeded Editors Picks, AfroBeats Now, Atomic Habits and invented live hosts are gone.
- Discover reads `GET /home/discover` (`editors_picks`, `trending`, `new_episodes`). Empty rails keep the section headers. Failed loads keep the existing chrome and Retry.
- Charts reads `GET /home/charts`. Music and Audiobooks stay empty until those category slugs exist. The creator banner uses `authSessionProvider.creatorAccess`, not the local claim singleton.
- Playlists & More reads `GET /home/playlists` (`yours`, `live`). Shorts remain navigation shortcuts, not a seeded catalog. Live rows use server host names and viewer counts.
- The nine See All screens call `GET /home/rails/{key}`. Quick Listen chips send `min_duration` / `max_duration`; African Voices chips send an allow-listed `country`.
- See All no longer wraps a nested `ProviderScope`, so catalog and session overrides reach the rail provider.
- Laravel discover `new_episodes` now emit the same typed item shape as trending. Rail filters remain server-authoritative; invalid `country=XX` is 422.
- Verification: `flutter analyze lib test` is clean. Focused Flutter runs passed `home_repository_test` (7), `home_destinations_test` (2) and the Home/See All catalog cases in `widget_test`. First Laravel filter of `MobileHomeDestinationsTest|DiscoveryAndHomeTest|HomeContractTest` was 11 passed / 1 failed (76 assertions); the failure was a duration-filter fixture overlap, then corrected. A later PHPUnit rerun hit a contended `pelevo_test` schema from overlapping migrate/drop connections, so the corrected rail case was not re-confirmed in this session. Device and golden acceptance remain pending.

### Batch 4 — Creator claim wizard (implemented; device acceptance pending)

- Existing relationship, claim-podcast and claim-method through claim-failed layouts are unchanged. Seeded Relationship Podcast, `hello@…`, `482731` and `pelevo-7f3a9e2b` are gone.
- Claim Your Podcast searches `GET /search` and Continue stays disabled until a real show is selected.
- Email path: `POST /shows/{id}/claims` `{method:email}` → masked RSS owner email → `POST /claims/{id}/verify`. Wrong codes stay on Enter Code. Conflicts open the existing failed screen. Success refreshes `GET /me` and only then shows You’re verified.
- Description path: start claim, show the server `PELEVO-VERIFY-…` token, copy that token, `POST /claims/{id}/description/confirm`. Review Check status polls `GET /claims/{id}` and does not invent success.
- `GET /shows/{id}` now includes `claimed_by_viewer` from `verified_show_claims`. The podcast page verified badge uses that flag, not `PodcastCreatorService`.
- Reel create still uses the local claim singleton until that module is wired.
- Verification: Laravel `CreatorClaimGateTest` passed (4 tests, 39 assertions), including `claimed_by_viewer` on `GET /shows/{id}` after email verification. Device and golden acceptance remain pending.

### Batch 5 — Creator Studio and Dashboard (implemented; device acceptance pending)

- Existing Creator Studio hub and Dashboard chrome are unchanged. Seeded Adesola Adeyemi, The Relationship Podcast, 18.4K / 126K / 4.8, percent gains and invented episode plays are gone.
- The hub loads only after a verified claim: `GET /studio`, then `GET /studio/shows`, `GET /studio/episodes?limit=3`, `GET /studio/audience` and `GET /studios` (team count only).
- Show cards use server `title`, artwork, `episodes_count` and `follower_count`. Dashboard overview uses `listeners_30d`, `followers` and `show_followers` only. Period chips stay visual and do not invent week/month/year series.
- `GET /studio` now also returns the accessible creator profile for a studio member, matching `/studio/shows` access. 403 `CLAIM_REQUIRED` keeps the existing claim CTA.
- Creator reels, audience, monetization, payouts and live remain later rows and stay unbound.
- Verification: `flutter analyze` on the studio files is clean. Focused Flutter `studio_repository_test` (3) and `studio_flow_test` (3) passed. Catalog `claim-success` still passes. Laravel `CreatorStudioWorkspaceTest` passed (2 tests, 45 assertions), including owner/member `GET /studio` and outsider `CLAIM_REQUIRED`. Device and golden acceptance remain pending.

### Batch 6 — Creator episodes and episode details (implemented; device acceptance pending)

- Existing episodes list and episode details chrome are unchanged. Seeded Ep 42 titles, 12.4K plays, 346 comments and The Relationship Podcast header are gone from those two screens.
- The list reads `GET /studio/episodes`. Tiles use server title, published date, `duration_seconds` and `availability` (`available` → Published). Play and comment counts stay hidden until the API has them.
- Details reads `GET /studio/episodes/{id}` after a list tap. A catalog deep link without an id uses the first server episode and does not invent one. Streams stay hidden. The comment thread uses the real episode id, not `episode-42`.
- `GET /studio/episodes` now returns an explicit episode contract plus show title/artwork. Search still says it is not available. 403 keeps the claim CTA.
- Verification: `flutter analyze` on the episode files is clean. Focused Flutter `studio_repository_test` (4) and `studio_flow_test` (6) passed. Laravel `CreatorStudioWorkspaceTest` passed (2 tests, 60 assertions), including episode list fields and `GET /studio/episodes/{id}`. Device and golden acceptance remain pending.

### Batch 7 — Creator reels and reel details (implemented; device acceptance pending)

- Existing Your Reels chrome, create card and All / Linked / Drafts chips are unchanged. Seeded Jay quotes, Ep 42 links, 12.4K views and 2.8K saves are gone from those two screens.
- The list reads `GET /studio/reels`. All is unfiltered, Drafts sends `state=draft`, Linked to Episodes sends `linked=1`. Tiles use server caption, episode title, published date and state. Views, comments and saves stay hidden.
- Details reads `GET /studio/reels/{id}` after a list tap or See All. A catalog deep link without an id uses the first server reel. Views stay hidden. The comment thread uses the real reel id, not `reel-jay`.
- `GET /studio/reels` now returns an explicit contract (caption, state, episode title, linked, thumbnail path). Create Reel remains the later create-reel row.
- Verification: `flutter analyze` on the reel files is clean. Focused Flutter `studio_repository_test` (5) and `studio_flow_test` (9) passed. Laravel `CreatorStudioWorkspaceTest` passed (2 tests, 77 assertions), including reel list/detail fields. Device and golden acceptance remain pending.

### Batch 8 — Create reel (implemented; device acceptance pending)

- Existing Create New Reel chrome, source cards, caption field, cover row and Public chip are unchanged. Seeded Ep 42 / Relationship Podcast are gone.
- From an Episode lists `GET /studio/episodes`. Nothing is preselected. The picker uses server titles only.
- Save as Draft calls `POST /reels/drafts` with caption and claimed `episode_id`. The server now rejects episode/show ids that are not in the creator's claimed studio.
- Create Reel does not fake publish. `POST /reels` still requires a processed `upload_id`, which this screen cannot send yet. Cover stays unavailable. Public is visual only.
- Verification: `flutter analyze` on the create-reel files is clean. Focused Flutter `studio_repository_test` (6) and `studio_flow_test` (11) passed. Laravel `CreatorStudioWorkspaceTest` passed (2 tests, 84 assertions), including claimed-episode draft create and outsider 422. Device and golden acceptance remain pending.

### Batch 9 — Creator monetization, payouts and audience (implemented; device acceptance pending)

- Existing Monetization, Transaction History/Details, Payout Settings, Add Payout Method, Audience, Followers and Top Supporters chrome is unchanged. Seeded ₦72,430 / BlessedP / Access Bank PLC / Noble Stan / 18.4K are gone.
- Monetization reads `GET /studio/monetization` for gift counts, payout counts, coin balances and masked tax state. Period dropdowns stay visual. Earnings series is not invented.
- Transactions read `GET /studio/transactions` (`kind` for Earnings/Payouts/Gifts/Reels). Details read `GET /studio/transactions/{id}`. Amounts stay in ledger units (PCN); no Naira conversion.
- Payout Settings reads `GET /studio/payout-settings`, `GET /payout-methods` and monetization balances. Add Payout posts `POST /payout-methods`. Finance sign-off still returns 503. Proof upload stays unavailable. Tax/currency/schedule rows still open later catalog screens.
- Audience overview uses workspace `GET /studio/audience` counts. Followers read `GET /studio/audience/followers`. Supporters read `GET /studio/audience/supporters`. Demographics, locations and listening-time series stay unavailable.
- The API now lists transactions, followers and supporters with explicit public fields. Encrypted tax details and payout destinations stay off the client.
- Verification: `flutter analyze` on the monetization and audience files is clean. Focused Flutter `studio_repository_test` (8) and `studio_flow_test` (18) passed. Laravel `CreatorStudioWorkspaceTest` passed (2 tests, 148 assertions). OpenAPI phase two passed (1 test, 63 assertions). Device and golden acceptance remain pending.

### Batch 10 — Creator episode drafts, live, payout slices and studios (implemented; device acceptance pending)

- Existing New Episode, Go Live, Tax Information, Payout Currency, Your Studios, Add Studio and Payout Schedule chrome is unchanged. Seeded Relationship Podcast / Love, Actually / ₦10,000 / Relationships topic / fake publish and live-room success are gone.
- New Episode posts `POST /studio/episodes` as a claimed-show draft. Publish/Schedule stay blocked until episode audio exists. Cover, audio upload and a publish time stay unavailable.
- Go Live posts `POST /studio/live` then `PATCH /studio/live/{id}` `{state:live}` using the claimed show. Notify/comments switches stay visual.
- Tax, currency and schedule send partial `PUT /studio/payout-settings`. Tax details stay encrypted server-side. Thresholds stay in ledger units (PCN); no Naira conversion.
- Your Studios lists `GET /studio/shows`. Add Studio searches `GET /search` (including RSS URL match) and continues into the existing claim-method flow instead of inventing a studio name.
- The API now creates episode drafts without audio, accepts weekly/monthly/manual payout schedules, and updates currency/tax/schedule independently.
- Verification: `flutter analyze` on the creator files is clean. Focused Flutter `studio_repository_test` (9) and `studio_flow_test` (24) passed. Laravel `CreatorStudioWorkspaceTest` passed (2 tests, 178 assertions). OpenAPI phase two passed (1 test, 73 assertions). Device and golden acceptance remain pending.

### Batch 11 — Gifts, coin wallet and comments (implemented; device acceptance pending)

- Existing Buy Coins, Coin Wallet, purchase result, gift receipt, episode/reel comment and report chrome is unchanged. Seeded 1250 coins, ₦ pack prices, Applause fallback receipts, Kemi/Jay threads and fake report success are gone from these screens.
- Coin store and wallet read `GET /gifts/wallet`, `GET /gifts/packs` and `GET /gifts/wallet/activity`. Amounts stay in PCN. Pack price is the store localized price or “Price unavailable”; Continue does not credit coins in demo mode.
- Purchase success only shows coins after `POST /iap/verify`. Failed shows the real store/server message. Receipt reads `GET /gifts/{id}` for a sender-owned gift and stays empty without one.
- Comments read `GET /comments` with `sort=newest|top|creator`. Empty is a zero-length list. Replies need a selected comment. Report posts `POST /reports` with mapped reasons (Spoiler → `other`); Submit does not snackbar success unless the server returns 201.
- The API now presents gift packs/catalog/send/IAP/receipt/activity without ledger secrets or verification payloads, and comments with author, likes, replies_count and is_mine/is_creator. Invalid comment sort is 422.
- Verification: `dart analyze` on the gift/comment files is clean. Focused Flutter `gift_repository_test` (2), `comment_repository_test` (2), `gift_flow_test` (4), `comment_flow_test` (4) and the catalog gift/comment widget cases (2) passed. Laravel `MobileGiftsTest|CommunityAndLiveTest|PhaseThreeGateTest|PhaseFourFinancialGateTest|OpenApiPhaseThreeContractTest` passed (18 tests, 249 assertions). Device and golden acceptance remain pending.

### Batch 12 — Reels feed, create and monetization (implemented; device acceptance pending)

- Existing Reels, create hub, record, upload, drafts, editor and monetization chrome is unchanged. Seeded Jay Shetty / Chude / 12.4K counts, GTBank, ₦128,450 and fake “Reel published” are gone from these screens.
- For You / Following / Trending read `GET /reels/for-you|following|trending`. Tiles use server creator name, caption, like/comment/save counts and viewer liked/saved/following. Stories are unique creators from the loaded For You list. Claim to Create uses `capabilities.creator_access` (catalog preview still uses the local claim flag for the existing router).
- Like, save, follow, not-interested and reel report call the matching APIs. Related podcast reads `GET /reels/{id}/related-show`. Gifts pass the server `creator_profile_id`. Linked-episode chips use server `episode_title` when present. Share links and earnings series stay “not available”.
- Record/upload still capture on-device. Drafts list `GET /reels/drafts` plus local capture files. Save as Draft posts `POST /reels/drafts` (or PATCH). Publish does not fake success; `POST /reels` still needs a processed `upload_id`.
- Monetization reads `GET /reels/monetization` (followers, qualified_views, eligible, opted_in, min_followers, min_views). Opt In posts `POST /reels/monetization/opt-in`. Catalog `forceStage` still selects progress/eligible/active chrome. CLAIM_REQUIRED keeps the claim CTA. No Naira conversion.
- The API now presents public feed items and draft/monetization profiles instead of raw table rows, omits not-interested reels from feeds, and returns config thresholds on monetization GET.
- Verification: `dart analyze` on the reels files reports no errors. Focused Flutter `reel_repository_test` (2) and `reel_flow_test` (4) passed. Catalog widget cases for reels navigation, claim-to-create, gifts, comments, linked episode and monetization opt-in passed. Laravel `OpenApiPhaseThreeContractTest` passed (1 test, 101 assertions). `PhaseThreeOperationsTest` passed on a later serial rerun (3 tests, 38 assertions). Device and golden acceptance remain pending.

### Batch 13 — Earn catalog, withdrawals and invite (implemented; device acceptance pending)

- Existing Earn, See All, isolated player, withdraw gateways/setup/amount/review/success and Invite Friends chrome is unchanged. Seeded Honest Bunch/Mindset cards, Naira/USD quotes, local payout linking and `PELEVO-ADESOLA` are gone.
- Earn home and See All read `GET /earn/shows` and `GET /earn/episodes`. Sections follow server show titles. Empty rails keep headers. Artwork uses `CachedNetworkImage` with the existing placeholder.
- Play starts `POST /earn/episodes/{id}/sessions`, heartbeats post ordered evidence, and complete uses a durable Idempotency-Key. Local tickers never credit coins. `EPISODE_LOCKED` keeps the lock chrome. A player deep link without a selected episode does not invent one.
- Paystack/PayPal setup posts `POST /payout-methods` and only counts as linked when `verified_at` is present. Flutterwave explains it is not offered by the payout API. Amount/review use server ECN coins and the wallet minimum. Confirm posts `POST /withdrawals` with Idempotency-Key reuse. Direct success stays empty without a server receipt.
- Invite reads `GET /me/invite` and creates a code with `POST /me/invite` when none is active. Copy/share use the server code and `pelevo://invite/{code}`.
- The API now presents public earn catalog/session/award, invite and withdrawal receipts. RSS URLs, nonce hashes, ledger ids, destinations and idempotency keys stay off the client.
- Verification: focused Flutter earn repository/flow/wallet tests passed 15; catalog earn/invite/withdraw widget tests passed 2. Laravel `MobileEarnWalletTest`, `SocialAndInvitationTest` and `PhaseFourFinancialGateTest` passed 18 tests / 133 assertions on `pelevo_test`. Dart analyze on the earn/invite files is clean. Device and golden acceptance remain pending.

**Next:** remaining profile destinations such as `profile-connected`. Keep existing layouts. Earn still needs Play Integrity/App Attest and isolated `audio_url` playback before it is production-ready.

### Batch 14 — Connected accounts (implemented; device acceptance pending)

- Existing Google, Apple and Facebook tiles and Manage/Connect chrome are unchanged. Seeded `adesola@gmail.com` is gone.
- The screen reads owner-scoped `GET /me/connected-accounts`. Linked tiles use the server email (or `Connected` when email is null). Empty loads show `Not connected`.
- Manage confirms then `DELETE /me/connected-accounts/{id}` and only refreshes after a `disconnected: true` receipt. Failed deletes keep the tile linked.
- Connect for Google/Apple explains that a verified provider token is required and posts nothing. Facebook is not accepted by `provider in:apple,google` and submits nothing.
- The API list/create present `id`, `provider`, `email`, `created_at` plus `meta.user_id`. `provider_subject` stays off the client.
- Verification: focused Flutter repository/flow tests passed 6; catalog settings/connected-accounts widget test passed. Laravel `SocialAndInvitationTest` and connected-account `IdentityLifecycleTest` cases passed 7 tests / 50 assertions on `pelevo_test`. Dart analyze on the connected-accounts files is clean. Device and golden acceptance remain pending.

### Batch 15 — Search and Browse (implemented; device acceptance pending)

- Existing Search and Browse catalog chrome is unchanged. Seeded Honest Bunch / Mindset / Afrobeats Vibes / Startup Stories results are gone.
- Search landing reads recent queries (`GET /search/recent`) and trending shows (`GET /home/charts`). Typing uses `GET /search?preview=1` so suggestions do not write history. Submit and voice use `GET /search` / `POST /search/voice`. Empty is a zero-length result list. People search stays unavailable. Playlist tiles bind only server editorial matches. Date/unplayed/explicit filters stay visual.
- Voice keeps Listening chrome and does not invent a transcript. Follow posts `POST /shows/{id}/follow` and only then confirms.
- Browse reads `GET /browse` / `GET /browse/categories` / `GET /browse/{slug}`. Music uses a `music` slug when published. New Collections uses `GET /home/discover` `new_episodes`. Following reads `GET /me/following`. Added chrome uses a real followed title, or a generic receipt when none was added.
- The API now presents search `query` plus shows/episodes/playlists without RSS/audio/GUIDs, preview history skipping, and browse categories/shows as `id`, `name`/`title`, `slug`/`author`, `artwork_url`.
- Verification: focused Flutter search/browse repository tests passed 4 and flow tests passed 6; catalog search/browse widget cases passed 2. Laravel `DiscoveryAndHomeTest` passed 5 tests / 57 assertions and `OpenApiPhaseSixContractTest` passed 1 test / 64 assertions on `pelevo_test`. Device and golden acceptance remain pending.

### Batch 16 — Podcast, episode and player catalog (implemented; device acceptance pending)

- Existing podcast, episode and player chrome is unchanged. Catalog IDs still map to the original views (`podcast-following` is Now Playing, `episode-transcript-search` is Reviews, `player-paused` is miniplayer over Search, `player-transcript` is Add Notes).
- Show pages read `GET /shows/{id}`, episodes, related and reviews. Follow/unfollow and write-review wait for the server receipt. Play Latest selects the first published episode. Instagram/Website, guests and invented 4.8 / 25K copy are gone.
- Episode pages read episode detail, chapters, transcript, notes and show reviews. Transcript 404 is empty. Notes are the owner row. Download posts `/episodes/{id}/downloads` and does not claim a local file. Queue add posts with the current version. Copy uses `pelevo://episode/{id}`. Sleep timer stays on-device and does not stop playback. Speed patches `/player/session`.
- Player chrome binds the selected episode, playback progress and session. Play/pause/seek/mark-played call session/playback APIs. Casting is unavailable. Miniplayer-over-search uses recent queries and charts; miniplayer-over-discover uses Home discover. Queue lists `/queue` items including `show_id`.
- Audio is not decoded locally (`just_audio` is not in this app). Session `playing` is a server flag, not proof that sound is playing.
- Verification: focused Flutter catalog repository/flow tests passed 15; catalog podcast/episode/player widget cases passed 3; search/browse/claim flow tests passed 9. Laravel `LibraryAndQueueTest`, `ListeningCoreTest`, `EpisodeContentTest` and `CreatorClaimGateTest` passed 14 tests / 119 assertions on `pelevo_test`. Device/golden/canonical-route acceptance remain pending.

**Next:** `ai-hub` through remaining AI, then library/downloads. Keep existing layouts.

### Batch 17 — Queue and stats catalog (implemented; device acceptance pending)

- Existing queue and stats chrome is unchanged. Catalog IDs still map to the original views (`queue-filter` is the add sheet, `queue-autoplay` is play-next confirm, `stats-goals` is download totals, `stats-weekly` is device split chrome).
- Queue reads `GET /queue` and `GET /player/session`. Remove, reorder, clear and play-next wait for versioned receipts. History reads presented `GET /library/recent`. Shuffle live posts a shuffled `PUT /queue`. Auto-download, add-to-playlist and clear-history are not offered.
- Stats read presented `GET /stats/me`: totals, 30-day daily rows, streak, achievements without `evidence`, top shows, categories and `downloads_count`. Range chips filter daily dates on the client. Invented 8h 42m, +18% and device/quality splits are gone.
- The API now presents stats lists, library recent public fields, download settings without `user_id`, and queue PUT/DELETE/reorder in OpenAPI.
- Verification: focused Flutter catalog/queue/stats repository and flow tests passed 16; catalog queue/stats widget cases passed 2. Laravel `ListenerStateTest` passed 3 tests / 37 assertions and `OpenApiPhaseSixContractTest` passed 1 test / 64 assertions on `pelevo_test`. Device and golden acceptance remain pending.

### Batch 18 — AI Hub, library and remaining notification states (implemented; device acceptance pending)

- Existing AI, library and notification chrome is unchanged. Catalog IDs still map to the original views (`ai-generating` is recommendations, `ai-transcript` is summary result, `ai-history` is highlights results, `library-1`…`12` keep their original states).
- AI Hub posts only `summary` / `chapters` / `transcript` jobs and reads `GET /ai/jobs/{id}` `output.text`. Recommendations bind `GET /home/recommendations` without invented match percents. Ask and highlights stay available as chrome and do not post invalid job types. Clear history does not claim a wipe.
- Library reads presented overview, playlists, collections, saved/liked/shows/recent, authorized downloads and settings. Create collection posts `name` only. Wi-Fi-only binds download settings. Auto-download of new episodes is not offered. Play All uses a real first item or honest empty copy.
- Notification detail states bind `view=new_episode`, authorized `GET /downloads`, streak plus recents, and `view=broadcast`. Invented Premium Offer / 7-day streak / offline-ready copy is gone.
- Verification: focused Flutter AI/library/notification repository and flow tests passed 14; catalog widget cases passed 3; account-feed cases including new-episode and broadcast passed. Laravel `LibraryAndQueueTest` passed 3 tests / 30 assertions on `pelevo_test`. Device/golden/canonical-route acceptance remain pending. This is not production-ready local audio or on-device AI.

**Next:** share cards, then downloads / device-sync basic / Premium. Keep existing layouts.

### Batch 19 — Share cards catalog (implemented; device acceptance pending)

- Existing share-card chrome is unchanged. Catalog IDs still map to the original views (`share-card-qr`…`stats` are template previews, `share-card-top` is the card list, `share-card-saved` is gallery result chrome).
- Templates read `GET /share-card-templates` (`id`, `name`, `version`). Cards read presented `GET /share-cards` and `GET /share-cards/{id}` without `user_id`, `public_token` or raw payload. Save and schedule post `POST /share-cards` for `episode|reel|show` only. Playlists stay visual chrome and cannot be posted.
- Device path: `share_plus` opens the system share sheet with a captured PNG + link; `qr_flutter` encodes the share URL into preview bitmaps; `RepaintBoundary` + `path_provider` export PNG; `gal` writes the Pelevo album after access grant; success is claimed only after a real gallery write. Export is honest RGB PNG (no CMYK PDF). Guidelines bind `GET /cms/guidelines` via `CmsDocument.guidelines` with 404 “not published yet” and no local tip fallback.
- Verification: focused Flutter share-card repository/flow tests; catalog share-cards widget case; Laravel `MobileSupportTest` guidelines + `OpenApiPhaseSixContractTest` on `pelevo_test`. Physical-device/golden/canonical-route acceptance remain pending.

**Next:** downloads manager, device-sync basic and Premium. Keep existing layouts.

### Batch 20 — Downloads, device-sync basic and Premium (implemented; device acceptance pending)

- Existing downloads, device-sync-basic and Premium chrome is unchanged. Catalog IDs still map to the original views (`downloads-3` is downloading chrome, `downloads-6` is smart downloads, `premium-account` is registration chrome over the signed-in profile).
- Downloads bind presented `GET /downloads` (including `show_id`), settings, delete and `GET /storage`. Wi-Fi and max-storage wait for PATCH receipts. Smart downloads, SD card, local encode quality and invented GB/progress stay unavailable.
- Device sync binds devices, pairing codes, revoke, sign-out-all, sync pull/conflicts, storage and download limits. Invented 3.2 GB / 75% / MacBook seeds are gone.
- Premium binds plans (`price_minor` + currency), me, invoices, exclusive, checkout (Paystack/Flutterwave + Idempotency-Key) and restore. Checkout does not invent entitlement. Exclusive omits `audio_url` and returns 403 without entitlement.
- Verification: focused Flutter downloads/device-sync/premium repository and flow tests; catalog widget cases. Laravel gates on `pelevo_test`. Device/golden/canonical-route acceptance remain pending.

**Next:** lock-screen notifications (device-sync expanded already recorded as Batch 21). Keep existing layouts.

### Batch 21 — Device-sync expanded catalog (implemented; device acceptance pending)

- All 40 expanded IDs (`sync-dashboard` … `device-connected`) keep original views. Fake 5-device / 3.2 GB / 68% / MacBook / 99.6% seeds are gone.
- Bound where API exists: devices list/select/revoke/sign-out-all, pairing code + QR of the code string (camera auto-pair not offered), `POST /devices/pair`, sync pull/conflicts resolve, backup create/restore, storage + clear cache. Preference tiles stay local with honest “not a server flag” copy. Encryption/activity analytics use only reported device/pull/conflict counts.
- Verification: Flutter device_sync repository/flow tests; catalog sync-dashboard widget case. Physical-device/golden acceptance pending.

### Batch 22 — Lock screen notifications (implemented; device acceptance pending)

- Existing lock-screen chrome is unchanged. Catalog IDs still map to the original views (`lock-download-complete` keeps Ready offline as catalog state text; alert copy no longer claims local offline files).
- Settings and quiet hours bind `GET/PATCH /notification-preferences`. Privacy binds presented `GET/PUT /notification-lock-rules` (`show_title`, `show_body`, `sensitive_hidden` only). History binds inbox history and confirmed clear.
- Alert previews bind new-episode inbox, library recent, authorized downloads (including nearest `authorized_until`), and recommendations. Playlist-update and live lock push stay unavailable. Style, controls, sound, DND, snooze, custom rules, widgets, focus and analytics stay honest OS/chrome-only without fake success claims.
- Verification: focused Flutter lock-rules repository and lock flow tests; catalog lock widget case. Laravel PhaseSix lock-rules presentation and OpenAPI phase six contract on `pelevo_test`. Device/golden/canonical-route acceptance remain pending. This is not production-ready OS lock delivery, media-session controls or store notification channels.

**Next:** operator Firebase credentials (`google-services.json` / `GoogleService-Info.plist` + `FCM_SERVER_KEY`) for remote push while the app is killed; then remaining live catalog destinations. Keep existing layouts.

### Batch 23 — Lock-screen media session and alert delivery (implemented; Firebase credentials pending)

- `just_audio` + `audio_service` + `audio_session` play episode `audio_url` and publish Android/iOS lock-screen media controls (play/pause/skip/seek). Player play/pause/seek/speed sync the server session when possible but keep local transport if sync fails.
- Local lock-visible alerts use `flutter_local_notifications` channels, snooze schedules, and “Enable Lock Screen Alerts” which mirrors unread inbox items after notification permission. `POST/DELETE /me/push-tokens` stores encrypted FCM/APNs tokens; `PushDispatch` sends when `FCM_SERVER_KEY` is set. Live → `live` creates follower in-app (+ push when configured) notifications.
- OS DND/Focus modes and home-screen widgets remain OS-owned. Style layout chrome stays local. App IDs are aligned to the Firebase-registered Pelevo app `com.podemerald.pelevo`. `firebase_core` / `firebase_messaging` register FCM tokens via `POST /me/push-tokens` when the user enables lock-screen alerts.

### Batch 24 — Closed-beta completion pass (implemented; device/golden/ops acceptance pending)

- **Reel publish:** `POST /uploads` → PUT bytes → complete → poll `processed` → `POST /reels` from the reel editor (`reel_upload.dart`).
- **Earn:** isolated `just_audio` playback of `audio_url`; integrity via Firebase App Check / staging HMAC (`EarnIntegrity` + `EarnIntegrityVerifier`).
- **Downloads:** authorize then save bytes under app documents; player prefers local file paths.
- **Live listener:** `GET /live` + `GET /live/{id}` screens; Home Live Now → `/live/:id`; public routes allowed signed-out.
- **Canonical routes:** `/shows/:id`, `/episodes/:id`, `/reels/:id`, `/live`, `/live/:id` (plus existing `/screen/:id`; `/catalog` debug-only).
- **Creator episode media:** `POST /studio/episodes/{id}/audio` + `POST .../publish`; New Episode picks audio and publishes/schedules.
- **Google/Apple Sign-In:** `POST /auth/social` and connected-accounts link; Facebook stays unavailable.
- **Release hardening:** demo IAP gated to debug/`PELEVO_ALLOW_DEMO_IAP`; Sentry via `PELEVO_SENTRY_DSN`; see `RELEASE.md`.
- **CMS:** migration publishes terms/privacy/guidelines placeholders (replace before store listing).
- **Still operator/QA:** APNs `.p8` in Firebase, killed-app FCM proof, golden/device acceptance, signed Play/App Store builds, production `EARN_INTEGRITY_URL`.

---

## 1. Honest assessment of the repo today

### What is already production-grade

- Dark design system: `PelevoColors`, `PelevoSpacing`, `PelevoRadii`, `PelevoMotion`, Roboto Condensed (`lib/core/theme/app_theme.dart`)
- Shared chrome: `PelevoPage`, `PelevoButton`, `PelevoBottomNavigation`, sheets, snackbars (`lib/core/widgets/pelevo_widgets.dart`)
- Screen inventory as `PelevoScreenSpec` — every designed state has an id
- Feature folders that match the product (`features/earn`, `reels`, `gifts`, `creator`, …)
- Real device work already started:
  - `GiftWalletService` — Play/App Store IAP + `GiftPurchaseVerifier` hook
  - `ReelCreateService` — camera/gallery, 60s cap, local drafts
  - `CommentService` — sort, pin, hide, 400 chars, 15-minute edit
  - `EarnPlaybackSession` — isolated from the main player, duration awards, 72h lock
  - `EarnWalletService` — Paystack / PayPal / Flutterwave withdrawal machine
  - `ReelsMonetizationService` — 100 followers / 1,000 views, monthly payout copy
  - `PodcastCreatorService` + router redirect for creator-only reel screens
  - `ReelEpisodeLinkService` — reel → episode map
- Dependencies already chosen: Riverpod, go_router, Dio, Hive, SharedPreferences, IAP, image_picker, video_player, permission_handler
- `main.dart` already boots `PodcastCreatorService`, `GiftWalletService`, `CommentService` into `ProviderScope`

### What is not production

| Gap | Reality |
|---|---|
| Routing | `/screen/:id` showcase router, not product routes |
| Data | Hardcoded shows, reels, comments, wallets |
| State | Process-wide singletons (`*.instance`) instead of Riverpod repositories |
| Dio | Created, no `baseUrl`, no interceptors, no auth |
| Catalog | `/catalog` is a designer tool — keep it behind a debug flag |
| Auth | Buttons `go()` to the next screen with no tokens |
| Earn / gifts | Credit locally; server never sees it |
| Screen lists | Some boards are visual **states** of one screen (`library-1`…`12`), not 12 destinations |
| Persistence | Prefs keys (`pelevo_coin_balance`, `podcast_creator_claimed`) will fight the API if kept |

Treat the current app as a **high-fidelity prototype with islands of real logic**. Production Flutter is a migration, not a rewrite from zero.

---

## 2. Target architecture

```
lib/
  app.dart                 # PelevoApp + production GoRouter
  main.dart                # bindings, ProviderScope overrides
  core/
    theme/
    widgets/
    config/                # Env, /me/config cache
    network/               # Dio, interceptors, envelope parser
    storage/               # Secure token, Hive caches
    router/                # Auth / onboarding / claim redirects
  domain/                  # immutable entities (Show, Episode, Wallet…)
  data/
    dto/
    repositories/
    local/
  features/
    <same folders as today>
      application/         # Riverpod notifiers
      data/                # feature repository if isolated
      presentation/        # existing screens, stripped of hardcoded lists
```

Rules:

1. **Screens stay in `features/*/`. ** Do not explode a new UI kit.
2. **No new singleton services.** Port `GiftWalletService`, `CommentService`, `EarnPlaybackSession`, `EarnWalletService`, `ReelCreateService`, `ReelsMonetizationService`, `PodcastCreatorService`, `ReelEpisodeLinkService` to Riverpod notifiers backed by repositories.
3. **Riverpod is the app state.** `provider` can leave. `ChangeNotifier` is acceptable only during a short port.
4. **Hive** = offline cache (library, progress, drafts, `/me/config`). **flutter_secure_storage** = tokens. **SharedPreferences** = flags (onboarding seen, last tab).
5. **Dio** is the only HTTP client. One instance, injected.

---

## 3. Environment & bootstrap

```
lib/core/config/env.dart
```

- `API_BASE_URL` — dart-define per flavor: `dev` / `staging` / `prod`
- `SENTRY_DSN`
- `PAYSTACK_PUBLIC_KEY` (checkout only; secret keys never in the app)

`main.dart` already initializes Hive + prefs + three services. Production bootstrap:

1. `WidgetsFlutterBinding.ensureInitialized()`
2. `AppServices.initialize()`
3. Load tokens from secure storage
4. Create Dio with base URL + auth interceptor + 401 refresh
5. Prefetch `/me` and `/me/config`
6. `runApp(ProviderScope(...))`

`dioProvider` today has timeouts and `Accept: application/json` — keep those; add:

- `Authorization: Bearer`
- `X-Device-Id` (stable UUID in secure storage)
- `X-App-Version`
- `Idempotency-Key` on money POSTs
- Envelope unwrap; map `error.code` to typed exceptions

---

## 4. Routing: from catalog to product

Keep `/catalog` and `/screen/:id` in **debug / profile** so design review does not die. Production `initialLocation` becomes a resolver:

```
splash → (seen onboarding?) → auth → (phone verified?) → permissions → home
```

### Product route map (replace showcase ids)

| Product route | Replaces showcase ids | Tab |
|---|---|---|
| `/splash` | `splash` | — |
| `/onboarding` | `onboarding-*` (page view, not 5 routes) | — |
| `/auth/sign-in` | `auth-sign-in` | — |
| `/auth/register` | `auth-create-account`, `auth-account-created` | — |
| `/auth/verify-phone` | `auth-verify-number` | — |
| `/auth/forgot` | `auth-forgot-password`, `auth-check-email` | — |
| `/permissions` | `permissions-*` | — |
| `/home` | `home-feed` personalized modules | Home |
| `/home/discover` · `/home/charts` · `/home/playlists` | sibling Home stack screens, not nested tabs | Home |
| `/home/continue-listening` · `/home/made-for-you` · `/home/quick-listen` · `/home/because-you-listened` | matching `home-*` See All states | Home |
| `/home/trending` · `/home/following` · `/home/african-voices` · `/home/try-new` · `/home/topics` | matching `home-*` See All states | Home |
| `/live/:id` | Home **Live Now** tiles | — |
| `/search` | `search*` including filters, people, voice | Search |
| `/browse` · `/browse/:slug` | `browse*` including `browse-music` | Search stack |
| `/shows/:id` | `podcast-*` | — |
| `/episodes/:id` | `episode-*` | — |
| `/player` | `player-*` (full + miniplayer overlay) | overlay |
| `/queue` | `queue-*` | — |
| `/library` | `library-1` hub | Library |
| `/library/playlists` · `/library/playlists/:id` | `library-2`, `library-3` | Library |
| `/library/collections` · `…/:id` · `/new` | `library-9`…`11` | Library |
| `/library/saved` · `/liked` · `/shows` · `/recent` | `library-4`, `7`, `6`, `8` | Library |
| `/library/settings` | `library-12` | Library |
| `/downloads` | `downloads-*` + `library-5` | Library stack |
| `/notifications` | `notifications-*` | — |
| `/earn` | `earn`, `earn-all` | Earn |
| `/earn/player/:episodeId` | `earn-player` | Earn |
| `/earn/wallet` | `earn-wallet` | Earn |
| `/withdraw` … | `withdraw*` | Earn |
| `/reels` | `reels` + for-you/follow/trend | Reels |
| `/reels/create` | `reels-create` | gated |
| `/reels/record` · `/upload` · `/drafts` · `/editor` | matching ids | gated |
| `/reels/monetization` | `reels-monetization*` | — |
| `/profile` | `profile` | — |
| `/settings` | `settings-account`, `profile-*` | — |
| `/studio` | `creator-studio`, `creator-dashboard` | — |
| `/studio/shows` | `creator-studios`, `creator-add-studio` | — |
| `/studio/episodes` · `/studio/reels` | `creator-episodes`, `creator-reels`, details | — |
| `/studio/audience` | followers + supporters | — |
| `/studio/live` | `creator-go-live` | — |
| `/studio/payouts` | settings, add, schedule, currency, tax | — |
| `/claims/*` | `claim-*` + `relationship-podcast` | — |
| `/premium/*` | `premium-*` | — |
| `/ai` | `ai-*` | — |
| `/stats` | `stats-*` including achievements | — |
| `/devices` | `device-sync-basic-*` **and** expanded device/sync/backup ids | — |
| `/share-cards` | `share-card-*` (one wizard + library) | — |
| `/gifts/store` · `/gifts/wallet` | `gift-coin-store`, `gift-wallet`, IAP results, receipt | — |
| `/help` · `/invite` · `/about` | `profile-help`, `profile-invite`, `profile-about` | — |

`PelevoBottomNavigation` already maps indices to home / search / library / earn / reels. Keep that contract; only change the paths.

### Redirects to preserve

From `lib/app.dart`:

```
reels-create | reels-record | reels-upload | reels-drafts | reels-editor | creator-create-reel
  → if !claimed then /shows/:id or /claims
```

In production, `claimed` comes from `/me.creator.claimed`, not `PodcastCreatorService`.

---

## 5. How to read the screen catalog (critical)

Many `PelevoScreenSpec` entries are **states of one screen**, not destinations:

| Catalog IDs | Production widget | Drive with |
|---|---|---|
| `home-feed` | Personalized Home feed | ordered typed modules from `HomeRepository.feed()` |
| `home-continue-listening`, `home-made-for-you`, `home-quick-listen`, `home-because-you-listened` | Home See All | section-specific repository query + local filter state |
| `home-trending`, `home-following-new`, `home-african-voices`, `home-try-new`, `home-topics` | Home See All | ranked, followed, regional, category, and topic queries |
| `library-1` | Library hub | loaded shelves |
| `library-2` / `3` | Playlists list + detail | `/playlists` |
| `library-4` / `7` | Saved / liked | those endpoints |
| `library-5` | Downloads (or deep-link `/downloads`) | download repo |
| `library-6` / `8` | Followed shows / recently played | `/library/shows`, `/recent` |
| `library-9`…`11` | Collections grid / create / detail | `/collections` — **not a filter** |
| `library-12` | Library settings | prefs |
| `notifications-1`…`12` | one inbox | type filter + empty + selection |
| `downloads-1`…`12` | one downloads hub | active / smart / storage / offline |
| `player-*` | `FullPlayer` + **miniplayer** | see mapping below — **not** paused/buffering/offline |
| `queue-*` | `QueueScreen` | empty, editing, shuffle, play-next |
| `premium-*` | premium flow | plan / payment / active |
| `ai-*` | `AiHub` + job status | intro vs result |
| `reels-monetization*` | one screen | `ReelsMonetizationStage` from API |
| `gift-purchase-success/failed` | result after IAP | `GiftPurchaseStage` |
| `claim-success/failed` | claim result | API status |
| `podcast-unavailable` / `podcast-loading` | show screen | 404 / loading |
| `device-sync-basic-1`…`12` + expanded ids | device hub | pair / sync / backup / conflict / storage |

**Player catalog IDs vs `_PlayerView` (do not trust the id name alone):**

| Id | Actual view in `full_player_screens.dart` |
|---|---|
| `player-now-playing` | Full now playing |
| `player-paused` | Miniplayer over Search |
| `player-buffering` | Miniplayer over Discover |
| `player-sleep` | Sleep timer active |
| `player-speed` | 1.5x (or selected) speed |
| `player-device` | Casting to speaker |
| `player-chapters` | Chapter list |
| `player-transcript` | **Add notes** (empty notes) |
| `player-details` | Queue / up next |
| `player-video` | **Share options** |
| `player-completed` | **Download quality** |
| `player-offline` | **More options** menu |

Implement **one** `FullPlayer` plus a persistent miniplayer on Search/Discover/Home. Sleep and Cast are local. Notes, queue, share, and download are real product actions.

Playlists and collections need their own routes. Do not invent twelve `/library-n` paths. The catalog remains a visual QA checklist.

---

## 6. State layer — port plan for existing services

### 6.1 `AuthController` (new)

Replaces implicit navigation in `authentication_screens.dart`.

- login / register / social / OTP / logout
- Holds `User` + tokens
- `refreshListenable` for `GoRouter` (same pattern as `PodcastCreatorService.instance` today)

### 6.2 `AppConfigController`

Caches `/me/config`. Hides Earn tab if `earn_enabled` is false. Supplies withdrawal minimums so Flutter **stops hardcoding** `1250`, `0.004`, `₦4`, `72h`, `100/1000`.

Constants in `EarnPlaybackSession` and `ReelsMonetizationService` become **fallbacks** until config loads.

### 6.3 `CommentController` ← `CommentService`

Keep the model (`PelevoComment`, `CommentTarget`, `CommentSort`). Delete `_seed()`. Repository:

- list / post / edit / delete / like / pin / hide / report
- Optimistic like; rollback on failure
- Persist only an offline outbox, not fake counts (`_baseCounts` is demo)

Creator vs listener handle (`@adesola_podcaster` vs `@adesola_podlistener`) must come from `/me`, not a local claim flag.

### 6.4 `GiftWalletController` ← `GiftWalletService`

**Keep the IAP machine.** It is the most production-ready code in the repo.

Change:

- `initialize`: still query store products
- `GiftPurchaseVerifier`: POST `/iap/verify` with the receipt; return `data.credited`
- `sendGift`: POST `/gifts/send` **before** decrementing; local decrement only after `ok`
- Balance: from `/gifts/wallet`, not prefs `pelevo_coin_balance`
- Demo mode (`isDemoMode` when not iOS/Android): allowed in debug only; strip from release

Product IDs must stay aligned with admin `coin_packs` and the stores.

Keep `showPelevoGiftFlow` / `GiftComposerSheet` as the send UI (optional message). Do not build a sixth gift route for compose.

### 6.5 `EarnSessionController` ← `EarnPlaybackSession`

Keep isolation from the general player. That comment in code is a product rule.

Change:

- Start session → heartbeat timer posts to API, not only a local `Timer`
- `_complete` → `POST /earn/sessions/{id}/complete`; apply returned `coins` + `locked_until`
- `walletCoins` lives in `EarnWalletController`, not on the session
- Seek/scrub: still local UX, but complete is rejected if heartbeats are thin
- On `EPISODE_LOCKED`, render the existing lock UI

### 6.6 `EarnWalletController` ← `EarnWalletService`

Keep gateway enum and setup screens. `linkMethod` becomes verified-NUBAN / PayPal confirm APIs. `submitDraft` becomes `POST /withdrawals` with idempotency. History from API. Status strings (`Queued · Monthly (1st–5th)`) come from server, not concatenated in the client.

### 6.7 `CreatorClaimController` ← `PodcastCreatorService`

Boolean is not enough. States: `none | rss_pending | code_pending | in_review | claimed | rejected`. Router redirect uses `claimed` only.

### 6.8 `ReelCreateController` ← `ReelCreateService`

Keep local capture + documents-dir drafts. Publish:

1. `POST /reels/uploads`
2. PUT bytes to presigned URL
3. `POST /reels` with caption, tag, episode_link
4. Delete local file after `ready` (or keep until user confirms)

`publishActive()` today only drops the draft — that is the line to replace.

### 6.9 `ReelsMonetizationController`

Delete `configureForDemo`. Read `/reels/monetization`. `optIn()` hits the API.

### 6.10 `ReelEpisodeLinkController`

Replace the hardcoded map (`reel-jay` → `episode-42`) with `GET/PUT` on the reel.

---

## 7. Feature implementation order (client)

Match the API phases so Flutter is never waiting on theatre.

### Phase 0 — Client foundation

- Flavors, env, Dio, envelope, secure tokens, `/me`, `/me/config`
- Production router + auth redirects
- Hide `/catalog` in release
- Remote config driven tabs

**Done when:** cold start with a valid token lands on Home; invalid token lands on Sign In.

### Phase 1 — Listen

Wire the current Home modules listed in §7.1, Search, Browse, Show, Episode, Player + miniplayer, Queue, Library **playlists + collections**, and Downloads. The old Home summary referenced **Top Picks For You** and a separate **Episodes You Might Like** rail; those have been replaced in `HomeFeedScreen` by **Your Pick for Today** and **Made For You**.

Implementation tactic: keep widgets; replace literal lists (`monetizedShows`, home rails, search fixtures) with `AsyncValue<List<T>>` from repositories. Preserve loading/empty states already designed (`search-empty`, `podcast-loading`). Miniplayer catalog ids `player-paused` / `player-buffering` are overlays, not playback errors.

Player: introduce `just_audio` / `audio_service` (not yet in pubspec). Background playback is already promised by `permissions-background` and lock-screen designs. Add Cast only if you commit to `player-device`.

**Done when:** a real episode streams, progress survives kill, Library shows in-progress, a collection can be created.

### 7.1 Current Home experience and data contract

`HomeFeedScreen` in `lib/features/home/home_screens.dart` is the visual source of truth. Preserve this order when replacing mock content:

The feed chrome also includes a Profile shortcut and notification bell with unread state. Bind the greeting name and profile image to `GET /me`; bind the unread indicator to notification state rather than leaving the demo dot permanently visible.

1. Personalized greeting and mood prompt.
2. Mood discovery grid: **Learn Something**, **Money & Business**, **Feel Something**, **Faith & Purpose**, **Be Entertained**, and **Sleep & Unwind**.
3. **Your Pick for Today** — one explainable recommendation with duration, match percentage, recommendation reason, and Listen Now action.
4. **Continue Listening** — resumable episodes with position/duration and inline play/pause.
5. **Made For You** — episode recommendations with show, duration, and match score.
6. **Quick Listen** — episode recommendations filtered by `5–10 min`, `10–20 min`, or `30+ min`.
7. **Because You Listened** — similar shows/episodes with a source-listen explanation.
8. **Trending on Pelevo** — ranked content with play counts.
9. **New From People You Follow** — recent followed-show episodes with relative publish time.
10. **African Voices** — regional discovery filtered by Nigeria, Ghana, or Kenya.
11. **Try Something New** — category discovery for topics the listener has not explored.
12. **Surprise Me** — one-tap recommendation outside the listener’s usual pattern.
13. **Explore by Topic** — Business, Relationships, Society, Faith, Culture, Technology, Health, and Sports.
14. **Trending Shorts** — popular portrait short cards.
15. **Shorts You Might Like** — personalized portrait short cards with recommendation labels.
16. **Browse Categories** — Podcasts, Shorts, Audiobooks, and More.

The Home feature also contains nine registered See All states in `lib/features/home/home_see_all_screens.dart`:

- `home-continue-listening`
- `home-made-for-you`
- `home-quick-listen`
- `home-because-you-listened`
- `home-trending`
- `home-following-new`
- `home-african-voices`
- `home-try-new`
- `home-topics`

These are real list/filter destinations, not modal states. Production routes should use the `/home/...` paths in §4 while retaining the showcase ids for visual QA.

#### Repository shape

Do not make one HTTP call per Home module. `HomeRepository.feed()` should return an ordered list of typed modules so the server can rank, hide, or reorder modules without a client release. Use discriminated module keys such as:

```dart
sealed class HomeModule {
  const HomeModule({required this.key, required this.title});
  final String key;
  final String title;
}

// Examples: ContinueListeningModule, EpisodeRailModule,
// ShowRailModule, CategoryModule, ShortRailModule.
```

The client should additionally expose focused methods for See All and interactive filters:

- `continueListening()`
- `recommendations({RecommendationKind kind, int? maxDurationMinutes})`
- `trending()`
- `newFromFollowing()`
- `africanVoices({required String countryCode})`
- `categories({String? mood, bool unexploredOnly = false})`
- `topic(String slug)`
- `surpriseMe()`

Recommendation DTOs need `reason`, `match_score`, and `source_item` where applicable. Quick Listen needs `duration_seconds`; African Voices needs normalized country/region metadata. Every card still uses stable `show_id`, `episode_id`, or `reel_id` for navigation and analytics.

#### Existing API coverage and remaining Home gap

The Laravel API already provides:

- `GET /home/feed` with `continue_listening`, `new_from_following`, and `recommended_shows`
- `GET /home/discover` with new episodes and categories
- `GET /home/charts`
- `GET /home/playlists`
- `GET /home/recommendations` with materialized items and explanations
- `GET /reels/trending` and `GET /reels/for-you`

`GET /home/feed` can return a durable `home_feed_snapshots` result with `meta.freshness` and `snapshot_version`; otherwise it computes the three current rails and queues `MaterializeHomeFeed`. Preserve those metadata fields in the repository so stale-while-refresh behavior can be implemented without blanking the feed.

That is enough to start wiring the feed, but it does **not yet express the full Home UI contract**. `BuildHomeFeed` must evolve from three generic rails to the ordered typed modules above, or the missing modules must be derivable from documented focused endpoints. In particular, production data is still needed for mood discovery, Pick for Today, match scores, duration buckets, source-listen reasons, play-count ranking, country filters, unexplored categories/topics, and Surprise Me.

Use `/home/recommendations` for explainable personalized picks and `/reels/*` for short feeds; do not duplicate reel ranking in the Flutter client. Keep local ChoiceChip state for duration/country selection, but fetch or filter server-authoritative results through the repository.

#### Home sibling screens

The other Home screens are separate stack destinations:

- **Discover** (`home-discover`): Editors Picks, ranked Trending Now, and New Episodes.
- **Charts** (`home-charts`): Podcasts, Music, and Audiobooks segments; ranked rows with trend direction; creator CTA routed to Studio when claimed and the claim flow otherwise.
- **Playlists & More** (`home-playlists`): Your Playlists, Shorts shortcuts, and Live Now with listener counts.

`Live Now` is not on `HomeFeedScreen`. Playlists & More now reads live rows from `GET /home/playlists`. Public `GET /live` / `/live/:id` remain for a later dedicated live player. The Charts creator banner already reads `authSessionProvider.creatorAccess` from `/me`.

### Phase 2 — Account polish

Permissions flow should call `permission_handler` for real (reels already do). Profile edit (name, `@handle`, bio, avatar), following (people + shows), email prefs, connected accounts, audio quality, data saver, offline mode, sleep timer, notification prefs, help/FAQ, about. Logout must hit `/auth/logout` and drop tokens — today it only `go`s to sign-in.

### Phase 3 — Comments + Reels consume

Comments on episode/reel. For You / Following / Trending reels with `video_player` + prefetch. Gated create routes.

### Phase 4 — Reels create

Already half-built. Add upload pipeline + processing status UI (you already have drafts/editor).

### Phase 5 — Money

IAP verifier → API. Gift send. Earn heartbeats. Withdrawals. This is the phase that can lose the company if done client-side. **No optimistic wallet credit for IAP or earn complete.**

### Phase 6 — Creator studio

Claim wizard screens already exist (`claim-method` → success/fail). Bind them. Studio dashboards become `/studio` reads.

### Phase 7 — Premium

Reuse `_PremiumScreen` states; checkout via Paystack/Flutterwave in-app WebView or official SDKs; entitlement from `/premium/me`. Restore purchase for store-billed markets if you later add store subscriptions — today the UI shows Paystack/Flutterwave.

### Phase 8 — Sync, share cards, AI, stats, lock rules, live, invites

Large surface area, lower launch risk. Implement behind `/me/config` flags (`live`, `ai_hub`, `share_cards`, `referrals`). The **Live Now** UI already exists on Playlists & More; this phase binds it to public `GET /live` and ships it with `creator-go-live`. Invite code + bonus coins need the referral API before the share buttons go live.

---

## 8. Screen-to-repository cheat sheet

| Feature folder | Repository methods | Notes |
|---|---|---|
| `onboarding` | `AuthRepository.saveOnboarding` | local + PATCH `/me/onboarding` |
| `authentication` | `AuthRepository.*` | stop `context.go` on dummy success; include `auth-account-created` |
| `home` | `HomeRepository.feed/continueListening/recommendations/trending/newFromFollowing/africanVoices/categories/topic/surpriseMe/discover/charts/playlists` + `ReelRepository` + `LiveRepository` | current Home modules, sibling screens, all nine See All screens; greeting comes from `UserRepository`, mood/topic discovery from `CatalogRepository` |
| `search` | `SearchRepository` | debounce 250ms; voice upload |
| `browse` | `CatalogRepository` | include music category |
| `podcast` / `episode` | `ShowRepository`, `EpisodeRepository` | notes, like, save, queue |
| `player` / `queue` | `PlaybackRepository`, `QueueRepository` | audio_service + miniplayer; Cast optional |
| `library` / `downloads` | `LibraryRepository`, `PlaylistRepository`, `CollectionRepository`, `DownloadRepository` | isolate + path_provider; smart downloads |
| `notifications` | `NotificationRepository` | FCM token on login; typed filters |
| `comments` | `CommentRepository` | port service |
| `reels` | `ReelRepository`, `ReelUpload` | like, save, not-interested, episode link |
| `gifts` | `GiftRepository`, IAP | composer sheet + store |
| `earn` | `EarnRepository` | isolated player |
| `creator` | `StudioRepository`, `ClaimRepository`, `LiveRepository` | supporters = gifters |
| `premium` | `PremiumRepository` | |
| `ai` | `AiRepository` | poll jobs |
| `stats` | `StatsRepository` | streaks + achievements |
| `device_sync` | `DeviceRepository`, `SyncRepository`, `BackupRepository` | basic + expanded boards are one hub |
| `share_cards` | `ShareCardRepository` | render locally, upload PNG; schedule |
| `profile` | `UserRepository` | offline toggle, invite, help |
| `lock_screen` | prefs + `NotificationRepository.lockRules` | |

---

## 9. UI implementation rules (so the app still looks like Pelevo)

1. Use `PelevoPage` / `PelevoButton` / theme tokens. Do not introduce a second button style.
2. Max content width **520** is used on many focused screens. Home, Discover, Charts, Playlists & More, and Home See All intentionally use **760** via `_HomeShell` / `HomeSeeAllScreen`; preserve that wider rail layout.
3. Bottom nav colors are part of the brand (red/blue/yellow/green/purple). Do not gray them out.
4. Motion: `PelevoMotion.normal` + fade/slide already in `app.dart`. Reuse, do not add random heroes everywhere.
5. Artwork: move from `assets/home/*.png` to `CachedNetworkImage` with the same corner radius (`PelevoRadii.medium`). Keep assets as placeholders and integration-test fixtures.
6. Empty / error / loading: copy from the matching catalog state instead of a generic spinner.
7. `showPelevoMessage` is fine for ephemeral confirmation; money success should use the dedicated screens (`withdraw-success`, `gift-purchase-success`).

---

## 10. Offline, downloads, sync

Downloads screens already describe a product: wifi-only, cellular, expiry, storage cleanup.

Production:

- `background_downloader` or a small isolate + `dio.download` to app documents
- Encrypt or at least store under app sandbox
- `GET /downloads/authorize` returns a short-lived URL
- Offline player uses `player-offline` UI when the file exists and the network does not
- Sync: treat `playback_progress`, queue, library, and notification prefs as sync entities with `updated_at` + `device_id`. Conflicts use the screens already designed (`conflict-detected` … `conflict-resolved`) — do not invent a silent last-write-wins for playlists the user cares about

Earn and gifts are **online-only**. If offline, disable complete/send.

---

## 11. Permissions (real, not slides)

| Screen | Runtime permission | Already requested in code? |
|---|---|---|
| `permissions-notifications` | notifications | no — wire `Permission.notification` |
| `permissions-microphone` | microphone (voice search + reel record) | reel record only |
| `permissions-storage` | photos/videos/storage | reel upload only |
| `permissions-background` | ignore-battery / audio service | no |
| `permissions-devices` | nearby devices (Android 12+) | no |

The permission slideshow can stay as UX; each “Allow” must call the plugin and skip gracefully on deny.

---

## 12. Testing strategy

Current `test/widget_test.dart` is a stub. Minimum bar before store submit:

- **Golden / widget tests** for `PelevoButton`, bottom nav, earn lock banner, gift purchase stages
- **Controller tests** for earn award bands, withdrawal validation, comment edit window, reel duration reject — move those rules behind pure functions so they stay testable when the API also enforces them
- **Repository tests** with Dio `http_mock_adapter`
- **IAP**: keep demo path under `assert(() { ... })`; release tests use fake `InAppPurchase`
- **Router tests**: unauthenticated user cannot open `/studio` or `/reels/create`

QA should walk `/catalog` in debug and tick every state after data is live — that is why the catalog must remain.

---

## 13. Release engineering

`pubspec.yaml` is `1.0.0+1`. For stores:

- Flavors: `dev` (debug API), `staging`, `prod`
- Android applicationId + iOS bundle id per flavor
- ProGuard / R8 keep Play Billing
- `permission_handler` manifests for camera, mic, notifications, storage
- App Store IAP + Play Console products matching `pelevo_coins_*`
- Deep links: `https://pelevo.tld/shows/:id`, `/episodes/:id`, `/reels/:id` → production routes (share cards depend on this)
- Crash: Sentry; analytics: events for `earn_complete`, `gift_send`, `reel_publish`, `withdraw_submit` — no PII
- Hide `debugShowCheckedModeBanner` (already false)

Do not ship the designer catalog, seeded wallets (6,140 earn coins, 1,250 gift coins), or `configureForDemo` in release.

---

## 14. Anti-patterns to refuse while implementing

- Crediting coins in the client because “the UI needs to feel fast”
- Sharing `EarnPlaybackSession` progress with the main `PlaybackRepository`
- Using showcase ids (`library-7`, `notifications-3`) as production paths
- Treating collections as playlist aliases (the UI already separates them)
- Treating `player-transcript` as a transcript viewer (it is **notes**; transcripts live on `episode-transcript`)
- A second theme or Material default on new screens
- Calling admin APIs from the app
- Storing Paystack/Flutterwave **secret** keys in Dart
- Treating `PodcastCreatorService.claim()` as verification
- Publishing a reel by deleting the local draft only
- One “wallet” that mixes gifts, earn, and creator revenue

---

## 15. Definition of production-ready (Flutter)

The app is ready for a closed beta when:

1. A new user can register, verify phone, set interests, and see a **server** home feed covering at minimum resume, personalized picks with explanations, followed releases, trending, discovery filters, and both short rails.
2. Playback works in background and restores position on a second device.
3. Comments post to a real episode and appear on another account.
4. A claimed creator can upload a ≤60s reel that other users see after processing.
5. IAP credits gift coins only after `/iap/verify`.
6. A completed earn listen credits **once**, locks 72h, and appears in admin’s ledger.
7. Withdrawal below 1,250 coins is impossible even if the client is patched.
8. `/me/config` can hide Earn without a store release.
9. Release builds have no `/catalog` entry point.
10. Crash-free session rate is watched; money endpoints are traced.

---

## 16. How a developer should work day to day

1. Open the relevant showcase screen (`/screen/...` in debug) and note every piece of hardcoded copy and every button that only `showPelevoMessage`s.
2. Find the API row in `Admin_Dashboard_API.md` §6.
3. Add DTO + repository method + Riverpod notifier.
4. Bind the existing widget; do not redesign.
5. Add loading/error by reusing an existing catalog state.
6. Write a repository test with a fixture from the API envelope.
7. If a business number is involved, read it from `/me/config`, not a new constant.

That loop is the entire Flutter production program. The screens are done. The client is not — until every `instance` singleton speaks HTTP and every `/screen/:id` state has a real `AsyncValue`.

---

## 17. Complete Flutter folder coverage

`pelevoScreens` in `lib/app.dart` is the union of `entryFlowScreens` (onboarding through earn/creator/gifts/comments/reels), `discoveryDetailScreens` (search/browse/podcast/episode), `playbackInsightScreens` (player/queue/stats/AI), `libraryUtilityScreens` (library/notifications/downloads/device-sync-basic), and `premiumSystemScreens` (Plus + share cards + lock screen + device-sync-expanded). Nothing in `lib/features/` sits outside that graph except `showcase` itself.

| Folder | Wired into catalog? | Production work |
|---|---|---|
| `onboarding` | yes | page-view + persist interests |
| `authentication` | yes | tokens |
| `permissions` | yes | real `permission_handler` |
| `home` | yes, including nine `home_see_all_screens.dart` states | bind the ordered §7.1 module contract; use Reel API for shorts; keep Live Now paired with creator live |
| `search` | yes via discovery | search + voice |
| `browse` | yes via discovery | categories |
| `podcast` | yes via discovery | show API |
| `episode` | yes via discovery | episode API + notes |
| `player` | yes via playback | audio_service + miniplayer; fix id≠view names |
| `queue` | yes via playback | queue repo |
| `stats` | yes via playback | stats + achievements |
| `ai` | yes via playback | jobs |
| `library` | yes via utility | playlists **and** collections |
| `library_widgets` | supporting | keep |
| `notifications` | yes via utility | FCM + types |
| `downloads` | yes via utility | downloader |
| `device_sync` basic + expanded | yes (two boards, one hub) | sync/backup |
| `lock_screen` | yes via premium system | lock rules |
| `share_cards` | yes via premium system | card renderer |
| `premium` | yes | checkout |
| `profile` + `profile_support` | yes in entry flow | `/me`, help, invite |
| `comments` | yes in entry flow | port service |
| `gifts` | yes in entry flow | IAP + composer |
| `earn` + withdrawals | yes in entry flow | isolated player + payouts |
| `reels` + create + monetization + episode link | yes in entry flow | feed + upload + gating |
| `creator` (studio, claim, content, audience, management, monetization) | yes in entry flow | claim + studio + live |
| `showcase` | `/catalog` | debug only |
| `core/theme`, `core/widgets`, `core/services` | app chrome | keep; grow network/config |

**Settings that are client-only unless later synced:** dark mode (already forced dark), sleep timer, Cast, last tab index.

**Deep links to add besides catalog:** `pelevo://invite/{code}` for `profile-invite`.
