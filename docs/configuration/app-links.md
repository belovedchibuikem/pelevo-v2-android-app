# Android App Links (Pelevo)

Play Console warns when declared HTTPS deep links cannot verify against Digital Asset Links. Pelevo declares App Links for `https://pelevo.com/...` paths in `android/app/src/main/AndroidManifest.xml`.

## What must be true

1. `https://pelevo.com/.well-known/assetlinks.json` returns **HTTP 200**, `Content-Type: application/json`, **no redirect**.
2. The JSON `package_name` is `com.Podemeraldltd.pelevo`.
3. `sha256_cert_fingerprints` includes:
   - the **Play App Signing** certificate SHA-256 (Play Console → App integrity → App signing), and
   - the **upload key** SHA-256 (local keystore).
4. The release APK/AAB intent-filter uses `android:autoVerify="true"` only for hosts that pass (1)–(3).

Repo copy of the file: `api/public/.well-known/assetlinks.json`.

## Current failure mode (www)

Cloudflare redirects **all** `https://www.pelevo.com/*` traffic to `https://pelevo.com/*` (HTTP 301). Google’s verifier does **not** follow redirects, so:

```text
https://www.pelevo.com/.well-known/assetlinks.json  →  ERROR_CODE_REDIRECT
```

That is why Play reported deep links failing domain association. The apex host already verifies:

```powershell
curl.exe -sI "https://pelevo.com/.well-known/assetlinks.json"
curl.exe -sL "https://digitalassetlinks.googleapis.com/v1/statements:list?source.web.site=https://pelevo.com&relation=delegate_permission/common.handle_all_urls"
```

`www` is intentionally **not** in the `autoVerify` filter until the redirect exception below is live. Share and catalog links should prefer `https://pelevo.com/...`.

## Cloudflare fix (optional, to re-enable www App Links)

In Cloudflare → **Rules** → **Redirect Rules** (or the Bulk Redirect / Page Rule that sends www → apex):

1. Keep the www → apex redirect for normal pages.
2. Add an exception so these paths on `www.pelevo.com` are **not** redirected and return the same JSON as apex with HTTP 200:
   - `/.well-known/assetlinks.json`
   - `/.well-known/apple-app-site-association`
3. Confirm:

```powershell
curl.exe -sI "https://www.pelevo.com/.well-known/assetlinks.json"
# Expect: HTTP/1.1 200  and Content-Type: application/json  (not 301)
curl.exe -sL "https://digitalassetlinks.googleapis.com/v1/statements:list?source.web.site=https://www.pelevo.com&relation=delegate_permission/common.handle_all_urls"
# Expect: statements for com.Podemeraldltd.pelevo, no ERROR_CODE_REDIRECT
```

4. Then move the `www.pelevo.com` `<data>` entries back into the `android:autoVerify="true"` intent-filter (or a second verified filter that only lists www), ship a new Play build, and re-check **Grow → Deep links**.

## After shipping a build

1. Play Console → **Grow → Deep links** → confirm domains show as verified.
2. On a device with the Play-signed build:

```text
adb shell pm get-app-links com.Podemeraldltd.pelevo
```

`pelevo.com` should be `verified`.
