# Meta Aggregated Event Measurement (AEM) + ATE Troubleshoot

Meta's iOS attribution is its own beast. AEM (Aggregated Event Measurement) is Meta's parallel to SKAN, but with stricter prerequisites and silent-fail modes. This is the #1 source of "Meta + AppsFlyer integration is broken" support tickets.

## What AEM Actually Is

- **Aggregated Event Measurement** — Meta's privacy-preserving event measurement for iOS users who decline ATT
- Replaces deterministic Pixel/SDK-based attribution for ATT-denied users
- Meta no longer uses the old limited event-priority hierarchy for current app AEM flows, but AEM still depends on eligibility, event delivery, MMP/event mapping, and data-sharing setup
- Postbacks are Meta-proprietary, NOT raw SKAN postbacks
- AEM MAI (Mobile App Install) works automatically on Meta Ads Manager. AEM MAE (Mobile App Re-Engagement) still requires a verified deep link.

## Prerequisites Checklist (Most Common Failure: Skipping These)

If AEM doesn't appear in Meta Ads Manager OR install events don't show up, walk through this checklist in order:

### 1. App is published in App Store

AEM does NOT activate for TestFlight / unreleased apps. The app must have a live App Store listing.

### 2. App is added to Meta Business Manager

Business Settings → Accounts → Apps → Add → enter App Store ID

### 3. App is associated with the correct ad account

Business Settings → Accounts → Apps → click app → Assigned Assets → Ad Accounts → assign

### 4. Domain verification (if using Web + App attribution)

Business Settings → Brand Safety → Domains → Verify your primary domain via DNS TXT or HTML upload.

This is the silent killer. Without verified domain, AEM events from your web→app flow drop silently.

### 5. AEM no longer uses the legacy event-priority hierarchy, but setup still matters

Do not ask users to configure the old event-priority hierarchy. Current app AEM flows still require the app/ad account association, eligible events, connection method, MMP event mapping, and any MMP/Meta AEM data-sharing toggle to be enabled.

Verify events are flowing via Events Manager → your app → **Test Events** tab and in the MMP partner/postback logs.

### 6. App must have install volume

AEM aggregation requires minimum thresholds. New apps with <100 installs/day will see "data threshold not met" warnings.

### 7. iOS app event sending mechanism is configured

Choose ONE primary path:
- **Meta SDK direct** (valid, but often not enough for server-validated purchases/dedup)
- **MMP forwarding** (AppsFlyer, Adjust, Branch send events to Meta on your behalf via S2S)
- **Conversions API for App Events** (server-side, recommended modern approach)

## The MMP-Forwarded Path (AppsFlyer + Meta)

This is the most common setup. Walkthrough:

### AppsFlyer side

1. AppsFlyer Dashboard → Integrated Partners → Facebook → enable
2. Configure event mapping: AppsFlyer event name → Meta standard event name
3. Set "iOS Install Referrer" = enabled
4. Set "iOS Aggregated Events" = enabled (this is the AEM toggle)

### Meta side

1. Events Manager → your app → Aggregated Event Measurement → expect to see events flowing within 24-72h
2. If "AEM not selectable" in Ads Manager campaign creation:
   - **Cause A (most common):** no events received yet — Meta won't show AEM until the first event arrives. Install events count; give it 48h and verify via Test Events tab.
   - **Cause B:** app not associated with ad account (prerequisite #3)
   - **Cause C:** MAE (re-engagement) campaigns require a verified deep link — MAI (install) campaigns do not.

> **Historical context:** Older AEM docs and forum answers mention a limited event-priority hierarchy in Events Manager → Manage Events. Treat that as stale for current app AEM. Still verify MMP event mapping, connection method, and data-sharing toggles; "no hierarchy" does not mean "no setup."

### CUID (Customer User ID) — Necessary?

CUID is AppsFlyer's identifier you can attach to events for cross-device matching. Question from r/AppsFlyer:

> "Is setting a CUID recommended or required when using AppsFlyer + Meta Ads for iOS attribution?"

**Answer:** Not required for AEM, but recommended for:
- Cross-device deduplication (user installs on iOS, then uses web)
- Server-side Conversions API (Meta needs an identifier to match to a user — CUID hashed becomes Meta's `external_id`)
- LTV reporting in AppsFlyer dashboard

**If you set CUID, set it BEFORE `start()`:**

```swift
AppsFlyerLib.shared().customerUserID = userInternalId  // your hashed user ID
AppsFlyerLib.shared().start()  // CUID now associated with install
```

If set AFTER `start()`, install event already shipped without CUID — only future events get tagged. To fix, you'd need to re-attribute server-side via S2S API.

## ATE (Advertiser Tracking Enabled) Verification Error

Reddit pain point:

> "Meta ATE permission / verification error — AppsFlyer confirms data is sent correctly, but Meta shows error."

ATE = Advertiser Tracking Enabled, Meta's consent signal for whether advertiser tracking is enabled for the event. ATE verification errors usually mean events arrive at Meta but fail consent or payload validation.

### Common causes

1. **Missing required parameters in event payload.** Meta requires for purchase events: `currency` (ISO 4217), `value` (numeric), `content_ids` (for catalog matching). AppsFlyer's mapping must include these.

2. **Hashing mismatch.** Email/phone in `match_keys` must be SHA256 hashed lowercase trimmed. AppsFlyer auto-hashes if you send raw — but if you pre-hashed and AppsFlyer hashes again, double-hash → no match.

3. **Event timestamp out of window.** Events older than 7 days are rejected silently.

4. **App ID mismatch.** AppsFlyer's `appleAppID` config differs from Meta Business Manager's app ID.

5. **Test users polluting prod.** If you have test users with `isAdvertiserTrackingEnabled = true` set programmatically (not via real ATT), Meta detects the spoofed signal and rejects all events from that user → "verification error".

### Debug procedure

```bash
# In AppsFlyer dashboard:
# Apps → your app → Integration → Facebook → "View Logs" or "Postback History"
# Look for: 200 OK responses (good), 4xx (bad payload), 5xx (Meta side issue)

# Alternative: ask AppsFlyer support to share raw outbound request to Meta for a specific install_id
# They can provide it; cross-reference with Meta Events Manager → Test Events tab

# In Meta Events Manager:
# → your app → Test Events tab → enter your test device's IDFV
# → Trigger an event in app → should appear within 30s
# → If does NOT appear: AppsFlyer isn't actually sending OR app config wrong
# → If appears with WARNING: read the warning text — usually parameter validation
```

## React Native + Expo Specifics

The Reddit post was RN + Expo. Common pitfalls:

1. **Expo SDK 50+ required** for AppsFlyer plugin. Older Expo versions break SDK init.
2. **Use `react-native-appsflyer` plugin in app.config.ts**, not Podfile direct integration. Expo prebuild conflicts otherwise.
3. **`waitForATTUserAuthorization` must be set in JS** before calling `appsFlyer.initSdk()`:

```typescript
import appsFlyer from 'react-native-appsflyer'

const options = {
  devKey: 'YOUR_DEV_KEY',
  appId: '1234567890',
  isDebug: __DEV__,
  onInstallConversionDataListener: true,
  timeToWaitForATTUserAuthorization: 60,  // ← THIS
}

appsFlyer.initSdk(options, console.log, console.error)
```

4. **ATT prompt must come from Expo's `expo-tracking-transparency`** OR a custom native module — Expo Go won't trigger ATT (dev client / standalone build only).

```typescript
import { requestTrackingPermissionsAsync } from 'expo-tracking-transparency'

const { status } = await requestTrackingPermissionsAsync()
// status: 'undetermined' | 'denied' | 'granted'
```

## Conversions API (CAPI) for App Events — The Modern Path

If your MMP integration keeps fighting AEM verification errors, consider going direct via Conversions API:

```bash
# Server-side POST to Meta
curl -X POST "https://graph.facebook.com/<GRAPH_VERSION>/<DATASET_ID>/events" \
  -d "access_token=APP_ACCESS_TOKEN" \
  -d 'data=[{
    "event_name": "Purchase",
    "event_time": 1683456000,
    "event_id": "unique-event-id",
    "action_source": "app",
    "user_data": {
      "fbc": "fb.1.1683456000.IwAR0...",
      "external_id": "hashed-cuid-here"
    },
    "custom_data": {
      "currency": "USD",
      "value": 9.99
    },
    "app_data": {
      "advertiser_tracking_enabled": 0,
      "application_tracking_enabled": 1,
      "extinfo": ["i2","com.app.bundle","1.0.0","123","17.0","iPhone15,2","en_US","UTC","Carrier","1170","2532","3.0","6","128000","64000","Europe/Istanbul"]
    }
  }]'
```

Only include hashed identifiers such as email, phone, CUID/external_id, IP address, or device identifiers when ATT and other applicable privacy consent allow tracking/measurement use. CAPI transport does not make those identifiers ATT-independent.

> **Critical:** `extinfo` is a **strict 16-position positional array** (Meta drops the event silently if positions are missing or out of order). Index meanings:
>
> | idx | meaning | example |
> |---|---|---|
> | 0 | extinfo version | `"i2"` (iOS) or `"a2"` (Android) |
> | 1 | bundle id | `"com.app.bundle"` |
> | 2 | bundle short version | `"1.0.0"` |
> | 3 | bundle version | `"123"` |
> | 4 | OS version | `"17.0"` |
> | 5 | device model | `"iPhone15,2"` |
> | 6 | locale | `"en_US"` |
> | 7 | timezone abbreviation | `"UTC"` |
> | 8 | carrier name | `"Carrier"` or `""` |
> | 9 | screen width px | `"1170"` |
> | 10 | screen height px | `"2532"` |
> | 11 | screen density | `"3.0"` |
> | 12 | CPU cores | `"6"` |
> | 13 | external storage size | `"128000"` |
> | 14 | external storage free space | `"64000"` |
> | 15 | timezone IANA name | `"Europe/Istanbul"` |
>
> AppsFlyer constructs this for you when forwarding via S2S. If you go direct, build it once in a helper. **Do NOT use `...` ellipsis or omit positions** — Meta's parser is positional, not by-name.

## Verification

A healthy Meta+AppsFlyer iOS setup has:

- ✅ AEM toggle visible in Ads Manager when creating app install campaign
- ✅ Events Manager → Test Events shows events from real device within 30s
- ✅ AppsFlyer dashboard "Facebook" partner row shows install count matching Meta's
- ✅ ATE verification: green checkmark in Meta app dashboard
- ✅ Postback delays under 6h for delivered installs

If any of those fails, walk back through prerequisites.

## Related

- `consent-gating.md` — Meta SDK consent flag handling
- `att-timing-and-events.md` — when to fire Meta events relative to ATT
- `adattributionkit-and-skan.md` — non-Meta SKAN postbacks
