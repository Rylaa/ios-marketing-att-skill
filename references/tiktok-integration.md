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

**1.5+** is the floor for new integrations:

- Token-based Test Events in TikTok Events Manager (no recompile needed to flip test mode)
- SKAdNetwork 4 + AdAttributionKit support
- Bundled `PrivacyInfo.xcprivacy` (Apple required tracking domain declarations)
- Improved deduplication keys for hybrid MMP setups

Older 1.3.x and 1.4.x builds work but lack the privacy manifest — App Store Connect will warn on submission.

## Initialization — Full Swift Example

The init order matters. TikTok auto-reads ATT, so it has to be initialized AFTER the ATT decision is known OR be configured to suppress its own prompt and wait for your central ATT manager.

```swift
import TikTokBusinessSDK
import AppTrackingTransparency

func bootstrapTikTok() {
    let config = TikTokConfig(
        accessToken: nil,                      // optional; only for server-side hybrid
        appId: "1234567890",                   // App Store ID (numeric)
        tiktokAppId: "7XXXXXXXXXXXXXXXXXX"     // TikTok-assigned app ID from Events Manager
    )

    // 1. SKAdNetwork — see ownership matrix below.
    //    If your MMP (AppsFlyer / Adjust / Branch / Singular) owns SKAN, disable here.
    config?.disableSKAdNetworkSupport()

    // 2. ATT prompt suppression — STRONGLY recommended for any app with a central ATT manager.
    //    Without this, TikTok SDK may call ATTrackingManager.requestTrackingAuthorization itself.
    config?.suppressAppTrackingDialog()

    // 3. (Optional) Disable automatic event tracking — useful if you wire events manually
    //    via TikTokBusiness.trackEvent(...) for stricter consent gating.
    // config?.disableAutomaticTracking()

    // 4. (Optional) Cold-start kill switch — if user has not yet consented, you can
    //    initialize the SDK in dormant mode and flip it on after ATT decision.
    // config?.disableTracking()

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
        TikTokBusiness.setTrackingEnabled(true)   // start sending IDFA-bearing events
    case .denied, .restricted, .notDetermined:
        TikTokBusiness.setTrackingEnabled(false)  // SKAN-only path
    @unknown default:
        TikTokBusiness.setTrackingEnabled(false)
    }
}
```

> **Order rule:** `initializeSdk` should fire from `application(_:didFinishLaunchingWithOptions:)` so install attribution begins immediately. ATT prompt timing is independent — see `att-timing-and-events.md`.

## ATT + IDFA Behavior

The TikTok SDK is ATT-aware out of the box. Three things you need to know:

1. **It auto-reads ATT status.** No need to pass IDFA manually — when authorized, SDK reads it via `ASIdentifierManager` itself.
2. **`suppressAppTrackingDialog()` blocks TikTok's built-in prompt.** Without it, on first init TikTok may call `ATTrackingManager.requestTrackingAuthorization` on its own schedule. Almost always undesired in apps that already manage ATT centrally — you get a duplicate or out-of-context prompt.
3. **`setTrackingEnabled(true)` is the on-switch after ATT granted.** Until it's called, IDFA-bearing payloads are not sent even if ATT is authorized. SKAN postbacks still work either way.

If you forget `suppressAppTrackingDialog()` and your app also calls `ATTrackingManager.requestTrackingAuthorization` from your own ATT manager, iOS will only show one prompt (the system dedupes), but the timing becomes nondeterministic — TikTok's may fire mid-onboarding before you wanted it.

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
let event = TikTokBaseEvent(name: "Purchase", eventId: "purchase-uuid-12345")
event.addProperty("currency", value: "USD")
event.addProperty("value", value: 9.99)
TikTokBusiness.trackEvent(event)
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
- SDK initialized but `setTrackingEnabled(false)` and ATT denied → expected SKAN-only flow, not a bug.

### "SKAN postbacks dropped"

- TikTok IDs missing from `Info.plist` `SKAdNetworkItems` (see list below).
- Both MMP and TikTok SDK writing CVs (see ownership matrix).
- App ID mismatch between SKAN postback receiver URL and TikTok-registered app.

### "Double-counted installs"

- Both MMP and TikTok SDK reporting installs without dedup. Pick one as system of record.
- Hybrid setup with mismatched `event_id` between SDK and MMP forwarding.

### "ATT prompt appearing twice" / "appears unexpectedly mid-flow"

- `suppressAppTrackingDialog()` not set in TikTok config.
- TikTok SDK initialized before your ATT manager registered, and TikTok's prompt fired first.

### "TikTok dashboard CV ≠ MMP dashboard CV"

- Schema mismatch — upload the same schema to both, or disable TikTok-side schema entirely (matrix row 1).

## TikTok-Specific SKAdNetwork IDs (Info.plist)

Add to `Info.plist` under `SKAdNetworkItems`:

```xml
<key>SKAdNetworkItems</key>
<array>
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>252b5q8x7y.skadnetwork</string>
    </dict>
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>59vjd3p6cw.skadnetwork</string>
    </dict>
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>k674qkevps.skadnetwork</string>
    </dict>
</array>
```

> **Pull from MMP master list quarterly.** TikTok rotates and adds SKAN IDs as they expand attribution coverage. AppsFlyer, Adjust, Branch, and Singular each publish a master list of all ~200+ active network IDs — sync your `Info.plist` against that list every quarter. The three above are the TikTok-specific anchors, but the full list is what most apps actually ship.

## Verification Checklist

A healthy TikTok iOS integration has:

- TikTok Business SDK 1.5+ in Podfile, not OpenSDK (unless also doing share/login)
- `TikTokBusinessSDK` initialized from `didFinishLaunchingWithOptions`
- `suppressAppTrackingDialog()` set unless you intentionally delegate ATT to TikTok
- SKAN ownership decided once, configured on both sides per matrix
- `tiktokAppId` and `appId` distinct values, both numeric
- TikTok SKAdNetwork IDs in `Info.plist`, MMP master list synced
- Test Events tab shows events from a real device within 30s
- Production builds NOT in debug mode

## Related

- `consent-gating.md` — gating event firing on ATT + GDPR consent
- `att-timing-and-events.md` — when to fire ATT prompt relative to SDK init
- `adattributionkit-and-skan.md` — SKAN/AAK details, MMP master ID lists, dual attribution
