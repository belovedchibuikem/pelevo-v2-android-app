# Backend subscription architecture

Audience: backend developers and system architects.

Pelevo Plus follows a Spotify-style tier: one paid membership, store-managed price and currency, access until the paid period ends. The phone is never the source of truth. `GET /premium/me` is the only authorization read the app uses. `active` and `in_grace_period` keep Plus. `expired` and `canceled` return the account to the free tier.

Store product ids already shipped in the app:

| Product id | Period |
| --- | --- |
| `pelevo_plus_monthly` (App Store) / `pelevo_plus_individual` + `monthly` base plan (Play) | 1 month |
| `pelevo_plus_yearly` (App Store) / `pelevo_plus_individual` + `yearly` base plan (Play) | 1 year, including the 1-month introductory free trial |

## 1. Two records, one projection

Keep account data, the subscription transaction log, and the entitlement projection in separate tables.

- `users` already exists. Do not replace it with a subscriptions-only user row. Subscriptions reference `users.user_id`.
- `user_subscriptions` is the current subscription. One row per store original transaction.
- `subscription_transactions` is the immutable charge and lifecycle log. Reporting and disputes read this table. Nothing here is updated in place.
- `premium_entitlements` is what `GET /premium/me` returns. Webhook workers write it. Clients do not.

A listener profile (`country_code` on the user) is a content preference. It is not the billing country and it does not set the Plus price.

Schema changes live in the Laravel API at `api/database/migrations` (`2026_10_21_150000` through `2026_10_21_150200`). Forge runs those on deploy against PostgreSQL. `users.id` is a ULID. Store billing columns are added to the existing `premium_subscriptions` table, and charges are appended to `subscription_transactions`. `provider_webhook_events` remains the webhook inbox. `updated_at` on PostgreSQL is maintained by `plus_set_updated_at()`.

## 2. What `GET /premium/me` returns

```json
{
  "entitlement": {
    "state": "active",
    "starts_at": "2026-08-10T00:00:00Z",
    "ends_at": "2026-11-10T00:00:00Z",
    "plan_id": "plan-yearly"
  },
  "subscription": {
    "id": "subscription-uuid",
    "state": "active",
    "provider": "apple",
    "current_period_start": "2026-08-10T00:00:00Z",
    "current_period_end": "2026-11-10T00:00:00Z",
    "plan_id": "plan-yearly",
    "cancel_at": null
  }
}
```

`provider` on the wire is `apple` or `google`. The database stores `ios_app_store` or `google_play_store`. Map at the edge.

`entitlement` is null when the account has never had Plus. While a subscription exists but no longer grants access, return `expired` or `canceled` so the app can label the membership. The app treats any other state as not Plus.

`cancel_at` is set when auto-renew is off and the paid period is still running. `state` stays `active` until `current_period_end`. That is the Spotify cancel: the member keeps Plus through the time they already paid for.

## 3. Webhook pipeline

Accept server notifications only. A successful store sheet on the phone does not grant Plus.

| Source | Path | Verify before enqueue |
| --- | --- | --- |
| App Store Server Notifications V2 | `POST /webhooks/app-store` | JWS signed by Apple |
| Google Play Real-time developer notifications | `POST /webhooks/google-play` | Pub/Sub push authentication, then the subscription purchase token via the Play Developer API |
| RevenueCat, if used as the abstraction | `POST /webhooks/revenuecat` | `Authorization` shared secret |

`POST /premium/store-purchase` is the same writer, used so the first unlock does not wait on webhook latency. Verify the receipt with Apple or Google, then run the `INITIAL_PURCHASE` transition. The `plan_id` in the request is a hint. The product id inside the verified receipt wins. Replay of the same original transaction id is a no-op success.

The transition rules are implemented in `lib/server/plus_subscriptions`. A host verifies the Apple JWS or Google Pub/Sub push, loads the Play subscription when needed, then calls `SubscriptionLedger.apply`. That package does not hold Apple root certificates or the Play service account.

Processing rules:

1. Verify the signature. Reject before any write.
2. Insert `webhook_inbox` keyed by the store notification id (`notificationUUID`, Pub/Sub `messageId`, or RevenueCat `event.id`). A duplicate insert returns 200 and stops.
3. Respond 200 as soon as the inbox row is durable. Do not call Apple or Google, and do not update entitlements, on the request thread.
4. A worker loads the inbox row, normalizes it to an internal event, and applies the transition inside one database transaction.
5. Store retries are safe because step 2 and the transaction unique key both deduplicate.

Normalize every source to these internal events:

| Internal event | App Store V2 | Google Play RTDN | RevenueCat |
| --- | --- | --- | --- |
| `INITIAL_PURCHASE` | `SUBSCRIBED` / `INITIAL_BUY`, `OFFER_REDEEMED` | `SUBSCRIPTION_PURCHASED` | `INITIAL_PURCHASE` |
| `RENEWAL` | `DID_RENEW` | `SUBSCRIPTION_RENEWED`, `SUBSCRIPTION_RECOVERED` | `RENEWAL`, `UNCANCELLATION` when access is still paid |
| `DID_FAIL_TO_RENEW` | `DID_FAIL_TO_RENEW`, `GRACE_PERIOD_EXPIRED` is not this event | `SUBSCRIPTION_IN_GRACE_PERIOD` | `BILLING_ISSUE` |
| `CANCELLATION` | `DID_CHANGE_RENEWAL_STATUS` with auto-renew off | `SUBSCRIPTION_CANCELED` | `CANCELLATION` |
| `EXPIRATION` | `EXPIRED`, `GRACE_PERIOD_EXPIRED`, `REFUND`, `REVOKE` | `SUBSCRIPTION_EXPIRED`, `SUBSCRIPTION_ON_HOLD`, `SUBSCRIPTION_REVOKED` | `EXPIRATION` |

`SUBSCRIPTION_ON_HOLD` and a refund drop access immediately. They are expirations, not grace.

### Transitions

Identify the subscription by `(store_platform, original_transaction_id)`. Apple original transaction id and Google purchase token (the first token in the chain) are that key. Link `user_id` from the app account id placed in `appAccountToken` (Apple) or obfuscated external account id (Google). If the token is missing, leave the row unassigned and do not guess from email. `POST /premium/store-purchase` from a signed-in user attaches the row.

Every transition appends one `subscription_transactions` row and then updates `user_subscriptions` and `premium_entitlements`.

**`INITIAL_PURCHASE`.** Insert `user_subscriptions`. Set `subscription_status` to `active`. Set `expiry_date` from the store expiry, not from the server clock. Set `is_in_intro_offer` when the verified payload is a free trial or a promotional price (the 1-month free offer, or any other store intro). Copy `billing_country_code`, `billing_currency`, and `amount_minor` from that payload. Project `premium_entitlements.state = active`.

**`RENEWAL`.** Load by `original_transaction_id`. Set `subscription_status` to `active`. Set `expiry_date` to the new store expiry. Clear `cancel_at` and `grace_period_ends_at` when the store has resumed billing. Set `is_in_intro_offer` false once the intro phase has ended. Advance the period by the store period: about one month for `pelevo_plus_monthly`, about one year for `pelevo_plus_yearly`, and the intro length on the first paid conversion. Do not add a fixed month to a yearly product. Record the currency and country charged on this renewal, which may differ from the previous row.

**`DID_FAIL_TO_RENEW`.** Do not remove Plus. Set `subscription_status` and the entitlement to `in_grace_period`. Keep `expiry_date` at the last paid end unless the store sends a grace end that is later. Set `grace_period_ends_at` from the store when it sends one. When it does not, use the store's configured billing-retry window (typically 3–7 days, longer if the console is configured that way). Access continues until `EXPIRATION`.

**`CANCELLATION`.** The member turned off auto-renew, or the store will not renew. Leave `subscription_status` as `active` (or `in_grace_period` if a retry is already running). Set `cancel_at` to `expiry_date`. Do not change the entitlement to `canceled` yet. Plus remains until the period ends. A later `RENEWAL` clears `cancel_at`.

**`EXPIRATION`.** Set `subscription_status` to `expired`, or `canceled` when `cancel_at` was already set or the store revoked the purchase. Set the entitlement to that same state and set `ends_at` to the store expiry. The app then treats the account as the free tier: ads return, Plus-only catalog locks. Do not delete the user, listening history, or the transaction log.

If several subscriptions exist, the entitlement follows the one with the latest `expiry_date` whose status is `active` or `in_grace_period`. When none qualify, project the most recently updated terminal status.

## 4. Region changes and currency

Store the billing storefront that arrived inside the verified transaction. Apple sends `storefront`. Google sends `regionCode` on SubscriptionPurchaseV2. RevenueCat sends `country_code`. Persist the ISO 3166-1 alpha-2 code (`NG`, `ZA`, `KE`) on both the subscription and the transaction row.

Do not geolocate the request IP. Do not copy `users.country_code` into `billing_country_code`. Do not reprice an existing subscription because a profile, SIM, or locale changed. Nigeria to South Africa changes the billed currency only when Apple or Google bills the next period on the new storefront. The previous transaction stays in the currency that was actually charged.

`amount_minor` uses the ISO 4217 minor-unit exponent:

| Storefront | Currency | Exponent | Example shelf | Stored `amount_minor` |
| --- | --- | --- | --- | --- |
| Nigeria | NGN | 2 | 1,600 | 160000 |
| South Africa | ZAR | 2 | 69.99 | 6999 |
| Kenya | KES | 2 | 399 or 419 | 39900 or 41900 |
| Ghana | GHS | 2 | 24 | 2400 |
| Egypt | EGP | 2 | 79 | 7900 |
| Morocco | MAD | 2 | 49 | 4900 |
| Ivory Coast | XOF | 0 | 1,800 | 1800 |
| Cameroon | XAF | 0 | 1,800 | 1800 |
| USD storefronts | USD | 2 | 2.99 | 299 |

An introductory free period stores `amount_minor = 0` and `is_intro_offer = true`. Finance reports convert with the dated `fx_rates` row for analytics only. Never rewrite a stored charge into another currency.

Shelf prices are configured per country in App Store Connect and Play Console. See [Plus storefront prices](../configuration/plus-storefront-pricing.md). The API does not convert ₦1,600 into another currency for display or for billing.

## 5. Free tier

Downgrade means the entitlement no longer grants Plus. It does not mean a second product row called Free, and it does not mean deleting `user_subscriptions`. Client clearance is `premium_entitlements.state` in `expired` or `canceled`, or a null entitlement. `pelevoPlusRemovesAds` is false in those cases, which is the free tier.
