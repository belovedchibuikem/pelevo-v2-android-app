# Pelevo Plus storefront prices

Plus prices are set in App Store Connect and Google Play Console. The app shows the formatted price returned for the signed-in store account. It does not convert a naira or dollar shelf into another currency.

**Google Play** uses one subscription product, `pelevo_plus_individual`, with `monthly` and `yearly` base plans. **App Store** uses `pelevo_plus_monthly` and `pelevo_plus_yearly`. Do not leave a country on automatic conversion from ₦1,600.

| Storefront | Monthly price |
| --- | --- |
| Nigeria | ₦1,600 NGN |
| South Africa | R69.99 ZAR |
| Kenya | KES 399 or KES 419 |
| Ghana | GH₵24 GHS |
| Egypt | EGP 79 EGP |
| Morocco | MAD 49 MAD |
| Ivory Coast | 1,800 XOF |
| Cameroon | 1,800 XAF |
| USD storefronts without a local currency (Tanzania, Uganda, and the same class of stores) | $2.99 USD |

Introductory offers are configured in the store. Pelevo Plus uses a **1-month free trial** (30 days):

| Play product / base plan | Google Play offer ID |
| --- | --- |
| `pelevo_plus_individual` / `monthly` | `one-month-free-trial-monthly` |
| `pelevo_plus_individual` / `yearly` | `one-month-free-trial-yearly` |

The paywall prints the free-trial badge only when Play / App Store returns that offer for the signed-in account. Returning subscribers who are not eligible see the standard price (for example ₦1,600/mo) with a **Resubscribe** CTA.

Access is not decided on the phone. Apple, Google, or the billing provider notifies the API, and the app reads `GET /premium/me`. `active` and `in_grace_period` keep Plus. `expired` and `canceled` return the account to the free tier.
