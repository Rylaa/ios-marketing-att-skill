# TikTok Business SDK iOS Integration

TikTok ads attribution on iOS depends on the TikTok Business SDK (not the OpenSDK), correct ATT-aware initialization, and an explicit decision about who owns SKAdNetwork — the MMP, a non-MMP SDK, or TikTok itself. Most "TikTok installs missing" tickets trace back to a missing decision in that ownership matrix or a misconfigured init flow.

## SDK Options — Pick the Right One

TikTok ships two iOS SDKs. Confusing them is the most common day-zero mistake.

| SDK | CocoaPods name | Use for | NOT for |
|---|---|---|---|
| **TikTok Business SDK** | `TikTokBusinessSDK` | Ad attribution, app event reporting, SKAN/CV management, Events API hybrid | Login / share flows |
| **TikTok OpenSDK** | `TikTokOpenSDK` | "Login with TikTok", "Share to TikTok" | Ad attribution — does NOT report installs or events |

If you only run TikTok ads, you only need `TikTokBusinessSDK`. If you also offer a TikTok-share button, install both — they coexist.

### Recommended version

Use the current 1.5+/1.6.x line for new integrations:

- Token-based Test Events in TikTok Events Manager (no recompile needed to flip test mode)
- SKAdNetwork ownership controls and ATT delay controls
- Bundled `PrivacyInfo.xcprivacy`
- Improved deduplication keys for hybrid MMP setups

Do not claim AdAttributionKit support unless the current TikTok SDK docs or your MMP integration explicitly confirm it. Older 1.3.7+/1.4.x builds include privacy-manifest support, but new work should not start there.

## Initialization — Full Swift Example

The init order matters. Current TikTok SDKs do not actively show the ATT dialog themselves, but they can delay initial flushing while your central ATT manager asks for authorization.

```swift
import TikTokBusinessSDK
import AppTrackingTransparency

func bootstrapTikTok() {
    guard let config = TikTokConfig.config(
        withAccessToken: "TIKTOK_ACCESS_TOKEN", // non-null; from TikTok Events Manager / Marketing API flow
        appId: "1234567890",                   // App Store ID (numeric)
        tiktokAppId: "7XXXXXXXXXXXXXXXXXX"     // TikTok-assigned app ID from Events Manager
    ) else { return }

    // 1. SKAdNetwork — see ownership matrix below.
    //    If your MMP (AppsFlyer / Adjust / Branch / Singular) owns SKAN, disable here.
    config.disableSKAdNetworkSupport()

    // 2. ATT wait — let your own ATT manager own the prompt.
    //    Current SDK headers mark disableAppTrackingDialog as deprecated because
    //    the SDK no longer actively calls the ATT dialog.
    config.setDelayForATTUserAuthorizationInSeconds(60)

    // 3. (Optional) Disable automatic event tracking — useful if you wire events manually
    //    via TikTokBusiness.trackTTEvent(...) for stricter consent gating.
    // config.disableAutomaticTracking()

    // 4. Do not use disableTracking as "dormant mode" unless you intend to stop
    //    tracking before init; disabled tracking can make events stay cached until
    //    tracking is explicitly enabled.

    TikTokBusiness.initializeSdk(config) { success, error in
        if let error = error {
            print("TikTok init failed: \(error.localizedDescription)")
            return
        }
        // SDK ready. Events fired before this callback are buffered.
    }
}

// Later, after ATT decision is finalized:
func tikTokATTUpdated(status: ATTrackingManager.AuthorizationStatus) {
    switch status {
    case .authorized:
        TikTokBusiness.setTrackingEnabled(true)   // allow event sending when privacy rules allow
    case .denied, .restricted, .notDetermined:
        TikTokBusiness.setTrackingEnabled(false)  // events stay cached; use only if this is your consent policy
    @unknown default:
        TikTokBusiness.setTrackingEnabled(false)
    }
}
```

> **Order rule:** `initializeSdk` should fire from `application(_:didFinishLaunchingWithOptions:)` so install attribution begins immediately. ATT prompt timing is independent — see `att-timing-and-events.md`.

## ATT + IDFA Behavior

The TikTok SDK is ATT-aware out of the box. Three things you need to know:

1. **It auto-reads ATT status.** No need to pass IDFA manually — when authorized, SDK reads it via `ASIdentifierManager` itself.
2. **`disableAppTrackingDialog` / `appTrackingDialogSuppressed` is deprecated.** Current public headers say the SDK will not actively call the ATT dialog. Use your own ATT manager and `setDelayForATTUserAuthorizationInSeconds` if you need a wait window.
3. **`setTrackingEnabled(false)` disables event sending and keeps events cached until re-enabled.** It is not just an "IDFA off" switch. Use it only when your consent policy requires pausing TikTok event delivery.

If your app wants IDFA-based TikTok signals, call your own `ATTrackingManager.requestTrackingAuthorization` at the right moment and let the SDK read the resulting status.

## SKAN Ownership Decision Matrix

This is the table that prevents 90% of TikTok+MMP attribution loss. Pick exactly one row and configure both sides accordingly.

| Scenario | TikTok SDK config | TikTok Events Manager schema |
|---|---|---|
| **MMP owns SKAN** (AppsFlyer / Adjust / Branch / Singular) | call `disableSKAdNetworkSupport()` | DO NOT upload schema |
| **Non-MMP SDK owns SKAN** but you want TikTok to honor a schema | call `disableSKAdNetworkSupport()` | DO upload schema (TikTok decodes for reporting only) |
| **TikTok SDK owns SKAN** (no MMP, or MMP delegated) | omit `disableSKAdNetworkSupport()` | DO upload schema |

Two failure modes to watch for:

- **Both MMP and TikTok SDK active for SKAN** → duplicate `updatePostbackConversionValue` calls; iOS only honors the latest, and you get nondeterministic CV truncation.
- **Schema uploaded to TikTok Events Manager but `disableSKAdNetworkSupport()` not called** → TikTok overwrites the MMP's CV writes. The MMP dashboard shows correct CVs, TikTok's dashboard disagrees, and the app's actual postback is whatever wrote last.

The CV schema you upload to TikTok Events Manager (when applicable) should match exactly what your MMP uses — pull it from the MMP's CV designer and paste into TikTok's UI.

## Hybrid MMP + SDK Setup

TikTok Business SDK supports hybrid: events forwarded **both** via your MMP (S2S) and via the SDK directly. TikTok deduplicates by `event_id`.

```swift
let event = TikTokBaseEvent(eventName: "Purchase", eventId: "purchase-uuid-12345")
event.addProperty(withKey: "currency", value: "USD")
event.addProperty(withKey: "value", value: 9.99)
TikTokBusiness.trackTTEvent(event)
```

Your MMP must forward the **same** `event_id` for the same logical event. AppsFlyer/Adjust/Branch all support a custom `event_id` field — set it explicitly to your client-generated UUID.

**Most apps prefer MMP-only** (omit the TikTok SDK call site, let MMP forward). Reasons:

- Single source of truth for event firing
- Simpler debugging (one place to look)
- No risk of dedup misses from typo'd `event_id`

Use hybrid only if:

- You need TikTok-side enrichment fields the MMP doesn't forward
- You're A/B testing MMP forwarding vs. direct SDK and want to compare
- You have a real-time use case where MMP S2S latency (~minutes) is too slow

## TikTok Events API (Server-Side)

For sensitive or verifiable events — purchases, refunds, server-validated subscriptions — fire server-side via TikTok Events API alongside or instead of the SDK.

```bash
curl -X POST "https://business-api.tiktok.com/open_api/v1.3/event/track/" \
  -H "Access-Token: $TIKTOK_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "event_source": "app",
    "event_source_id": "7XXXXXXXXXXXXXXXXXX",
    "data": [{
      "event": "Purchase",
      "event_time": 1714752000,
      "event_id": "purchase-uuid-12345",
      "user": {
        "ttp": "<TikTok cookie value if web>",
        "external_id": "<hashed user id>",
        "ip": "1.2.3.4",
        "user_agent": "..."
      },
      "properties": {
        "currency": "USD",
        "value": 9.99,
        "content_id": "sku_premium_annual"
      }
    }]
  }'
```

The `event_id` MUST match the SDK-side `event_id` exactly — that's how TikTok dedupes. Mismatch = double-counted purchases in the dashboard.

Use Events API for:

- **Refund-aware revenue** (SDK fires Purchase, server fires Refund)
- **Webhook-validated subscriptions** (App Store Server Notifications → your server → TikTok)
- **High-value events** where client-side trust is insufficient

## Test Mode

From SDK 1.5+, Test Events use **token-based** activation in TikTok Events Manager — generate a test token in Events Manager → Test Events → paste it into the dashboard, install the app on a device, and events appear within 30s.

**No code change needed** to enter or exit test mode. The token-based flow replaces the older `setLogLevel(.debug)` / manual debug toggle — those still work but are not the recommended path.

> **Production safety:** never ship a release build with `TikTokBusiness.setLogLevel(.debug)` or manual debug-mode flags. Production events tagged as test events will not appear in attribution reports — you'll think your app is silent when it's actually flowing to the test sink.

## Common Failure Modes

### "Events not appearing in TikTok Ads Manager"

- **TikTok app ID misconfigured.** `tiktokAppId` is the TikTok-assigned ID from Events Manager (long numeric, e.g. `7XXXXXXXXXXXXXXXXXX`), NOT your App Store ID. Apps regularly swap them.
- App Store ID (`appId`) wrong — should be the numeric App Store ID, not bundle identifier.
- App not associated with TikTok Ads account in Events Manager → Assets.
- SDK initialized with `setTrackingEnabled(false)` → events stay cached until tracking is re-enabled; do not confuse this with an automatic SKAN-only mode.

### "SKAN postbacks dropped"

- TikTok IDs missing from `Info.plist` `SKAdNetworkItems` (see list below).
- Both MMP and TikTok SDK writing CVs (see ownership matrix).
- App ID mismatch between SKAN postback receiver URL and TikTok-registered app.

### "Double-counted installs"

- Both MMP and TikTok SDK reporting installs without dedup. Pick one as system of record.
- Hybrid setup with mismatched `event_id` between SDK and MMP forwarding.

### "ATT prompt appears unexpectedly mid-flow"

- Current TikTok SDK headers say the SDK does not actively call ATT, so first check your own ATT manager, another SDK, or stale wrapper code still calling `requestTrackingAuthorization`.
- Remove stale ATT-dialog suppression assumptions from wrappers; use `setDelayForATTUserAuthorizationInSeconds` for TikTok wait behavior.

### "TikTok dashboard CV ≠ MMP dashboard CV"

- Schema mismatch — upload the same schema to both, or disable TikTok-side schema entirely (matrix row 1).

## TikTok-Specific SKAdNetwork IDs (Info.plist)

Do not hardcode a static TikTok ID list from this skill. TikTok/MMP SKAN IDs change, and apps often need the full MMP master list rather than a few TikTok anchors. Pull the current list from TikTok Events Manager or your MMP's current SKAN ID export and add it under `SKAdNetworkItems` when your app or partner setup requires it.

```xml
<key>SKAdNetworkItems</key>
<array>
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>current-id-from-mmp-or-tiktok.skadnetwork</string>
    </dict>
</array>
```

> **Pull from MMP master list quarterly.** TikTok rotates and adds SKAN IDs as they expand attribution coverage. AppsFlyer, Adjust, Branch, and Singular each publish master lists; sync your `Info.plist` against the list that matches your chosen SKAN owner.

## Verification Checklist

A healthy TikTok iOS integration has:

- TikTok Business SDK 1.5+ in Podfile, not OpenSDK (unless also doing share/login)
- `TikTokBusinessSDK` initialized from `didFinishLaunchingWithOptions`
- No stale ATT-dialog suppression wrapper usage; use TikTok's ATT delay setting and your central ATT manager
- SKAN ownership decided once, configured on both sides per matrix
- `tiktokAppId` and `appId` distinct values, both numeric
- TikTok SKAdNetwork IDs in `Info.plist`, MMP master list synced
- Test Events tab shows events from a real device within 30s
- Production builds NOT in debug mode

## Related

- `consent-gating.md` — gating event firing on ATT + GDPR consent
- `att-timing-and-events.md` — when to fire ATT prompt relative to SDK init
- `adattributionkit-and-skan.md` — SKAN/AAK details, MMP master ID lists, dual attribution
