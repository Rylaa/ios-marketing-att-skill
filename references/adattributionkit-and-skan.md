# AdAttributionKit + SKAdNetwork — Postback Layer Reference

The privacy-preserving attribution layer that works regardless of ATT state. Required for any iOS marketing in 2026+.

## SKAN vs AAK — Quick Picture

| Feature | SKAdNetwork (SKAN) | AdAttributionKit (AAK) |
|---|---|---|
| Introduced | iOS 14.0 (2020) | iOS 17.4 (2024) |
| Postback recipient | Ad network only (or MMP via re-direct) | Ad network + advertiser app developer |
| Re-engagement | SKAN 4 only (limited) | First-class support |
| Alternative marketplaces | No | Yes (EU DMA) |
| Conversion windows | Single window with 3 updates | 3 separate windows (0-2, 3-7, 8-35 days) |
| Postback delay | 24-48h | 24-48h (1st), 24-144h (2nd/3rd) |
| Status (2026) | Still required for backward compat | Recommended for new integrations |

**Apple evaluates BOTH frameworks together** when picking attribution winners. You don't choose one — you support both. SKAN IDs and AAK IDs share the same namespace (`.skadnetwork` IDs are accepted in `AdNetworkIdentifiers`).

## Crowd Anonymity Tiers (AAK)

The device decides postback granularity based on how many similar conversions it's seen recently:

| Tier | Source ID digits | Fine CV | Coarse CV | Publisher ID | Country |
|---|---|---|---|---|---|
| 0 | 2 | — | — | — | — |
| 1 | 2 | — | 1st postback only | — | — |
| 2 | 2-4 | 1st postback only | 2nd/3rd postbacks | — | — |
| 3 | 2-4 | 1st postback only | 2nd/3rd postbacks | Yes | Conditional |

**Implication:** small-volume campaigns get Tier 0/1 → almost no data. Optimize for high-volume creative groupings to climb tiers.

## Conversion Value Strategy

Conversion value (CV) is your one channel to communicate "what happened" inside the app back to the ad network. Two encodings:

- **Fine value**: integer 0-63 (6 bits). Available only in 1st postback at Tier 2+.
- **Coarse value**: `.low` / `.medium` / `.high`. Available in all tiers.

### Common Encoding Strategies

**1. Funnel Step (early-stage apps)**

```
0 = install only
1 = onboarding complete
2 = first key action (e.g. created project, viewed product)
3 = signup
4 = added payment method
5 = trial start
6 = subscription / first purchase
```

Coarse mapping: 0-1 = `.low`, 2-4 = `.medium`, 5+ = `.high`

**2. Revenue Buckets (revenue apps)**

```
0    = no purchase
1-15 = revenue $0.01-$15 (each value = $1 bucket)
16-31 = revenue $15-$50
32-47 = revenue $50-$200
48-63 = revenue >$200
```

**3. Hybrid (subscription apps) — single window**

```
Bits 0-2 (8 values): trial state (none, started, converted, churned, ...)
Bits 3-5 (8 values): revenue bucket
```

Pack with: `cv = (revenueBucket << 3) | trialState`

**4. Multi-window encoding (subscription apps — preferred over hybrid bit-packing)**

AAK/SKAN 4's 3 windows let you measure different things in different time windows. Better than fine-bit-packing because **windows survive even at low Tier coarse-only mapping**:

| Window | Days | What to encode | Coarse mapping |
|---|---|---|---|
| 1st (0-2d) | trial start state | `low` = no trial, `medium` = trial start, `high` = trial + key action |
| 2nd (3-7d) | trial conversion | `low` = trial active, `medium` = trial converted, `high` = upsell |
| 3rd (8-35d) | retention + LTV | `low` = churned, `medium` = retained 30d, `high` = upsell or annual |

Wire by calling `updateConversionValue(...)` again at the appropriate point in each window. Each call updates the value for the CURRENT window only.

This pattern dominates pure bit-packing because at Tier 0/1 (low volume), only coarse values arrive — you'd lose all your packed fine bits anyway. Multi-window keeps the signal at every tier.

### Setting Conversion Value

```swift
import AdAttributionKit  // iOS 17.4+

// First call MUST happen as early as possible after install — opens the conversion window
func applicationDidFinishLaunching() async {
    do {
        try await Postback.updateConversionValue(0, lockPostback: false)
    } catch {
        print("AAK initial CV failed: \(error)")
    }
}

// On each meaningful event, update upward
func userCompletedOnboarding() async {
    try? await Postback.updateConversionValue(
        1,
        coarseConversionValue: .low,
        lockPostback: false
    )
}

func userPurchased(amountUsd: Double) async {
    let revenueBucket = bucketize(amountUsd)
    try? await Postback.updateConversionValue(
        revenueBucket,
        coarseConversionValue: .high,
        lockPostback: true  // ← lock to send postback FAST (within 24-48h instead of waiting full window)
    )
}
```

**Lock semantics:** `lockPostback: true` finalizes the conversion value AND closes the current window early. Use it when:
- User has clearly converted to high-value (e.g. paid sub) — you want the postback now
- You don't expect further state changes in the current window

Don't lock too early or you lose ability to update if user does something more valuable later.

### SKAdNetwork Equivalent (still required for backward compat)

```swift
import StoreKit

// ❌ DO NOT call — deprecated since iOS 15.4, creates duplicate registrations
// SKAdNetwork.registerAppForAdNetworkAttribution()

// ✅ SKAN 4 (current) — supports 3 postback windows with separate fine/coarse values per window
SKAdNetwork.updatePostbackConversionValue(
    0,
    coarseValue: SKAdNetwork.CoarseConversionValue.low,
    lockWindow: false
) { error in
    if let error { print("SKAN CV update failed: \(error)") }
}
```

If you support both AAK and SKAN, call BOTH on every event update. Apple's framework deduplicates downstream.

### SKAN 4 Three-Window Model (parallel to AAK)

SKAN 4 (iOS 16.1+) introduced 3 postback windows mirroring AAK's structure:

| Window | Days post-install | Fine CV | Coarse CV |
|---|---|---|---|
| 1st (Postback Window 0) | 0-2 | available (Tier 2+) | always |
| 2nd | 3-7 | — | available |
| 3rd | 8-35 | — | available |

Use `lockWindow: true` to close current window early and trigger faster postback (24-48h vs full window duration).

### iOS 18+ AAK API — `PostbackUpdate` (preferred over single-value updates)

iOS 18 added the `PostbackUpdate` value type that lets you specify conversion type and lock semantics in one call:

```swift
import AdAttributionKit  // iOS 18+

let update = PostbackUpdate(
    fineConversionValue: 35,
    coarseConversionValue: .high,
    lockPostback: true,
    conversionTypes: [.install]   // or [.reengagement] or both
)
try await Postback.updateConversionValue(update)
```

Benefits:
- Explicit `conversionTypes` separation (install vs re-engagement updated independently)
- iOS 18.4+ adds `conversionTag` for sub-classifying conversions inside the same value
- Cleaner API for apps targeting iOS 18+

For iOS 17.4-17.x compatibility, keep using the older `updateConversionValue(value, coarseConversionValue:, lockPostback:)` signature.

## AttributionCopyEndpoint (Server-side Postback Mirror)

By default, AAK postbacks go to ad network only. Add this Info.plist key to also receive a copy on YOUR server — critical for MMP setups and your own analytics:

```xml
<key>AdAttributionKit</key>
<dict>
    <key>AttributionCopyEndpoint</key>
    <string>https://attribution.yourdomain.com</string>
    <key>OptInForReengagementPostbackCopies</key>
    <true/>
</dict>
```

Apple sends POST to: `https://attribution.yourdomain.com/.well-known/appattribution/report-attribution/`

Your server must:
- Accept HTTPS POST (TLS 1.2+, valid cert)
- Return 200 OK quickly (Apple retries on failure)
- Verify postback signature (Apple signs with their key)

Postback body (JSON):

```json
{
  "version": "5.0",
  "ad-network-id": "example.adattributionkit",
  "campaign-id": 42,
  "transaction-id": "uuid-here",
  "app-id": 1234567890,
  "attribution-signature": "base64-sig",
  "redownload": false,
  "source-app-id": 9876543210,
  "conversion-value": 35,
  "fidelity-type": 1,
  "did-win": true
}
```

## Required Info.plist for Publisher Apps (Showing Ads)

```xml
<key>AdNetworkIdentifiers</key>
<array>
    <string>example.skadnetwork</string>
    <string>example.adattributionkit</string>
    <!-- Add EVERY ad network's ID -->
</array>
```

For advertisers (apps being promoted), also add `SKAdNetworkItems`:

```xml
<key>SKAdNetworkItems</key>
<array>
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>v9wttpbfk9.skadnetwork</string>
    </dict>
    <!-- One entry per ad partner -->
</array>
```

Most MMPs (AppsFlyer, Adjust, Branch, Singular) maintain a master list of all ad network IDs you can copy-paste.

## Apple Ads Dual Attribution (since Apr 2025)

Since April 10, 2025, Apple Ads installs report through BOTH:

1. **AdAttributionKit + SKAN postbacks** (privacy-preserving, all users)
2. **AdServices API** (full IDFA-based, requires user to remain in App Store flow without leaving)

This means an Apple Ads install has 2 attribution paths, and you may see "double counting" in raw logs. MMPs deduplicate. WWDC 2025 added:

- Configurable attribution windows
- Overlapping re-engagement windows
- Country codes in postbacks (Tier 3 only, conditional)

## Re-engagement Attribution (AAK-only, AAK > SKAN)

AAK supports first-class re-engagement: a user who ALREADY has the app installed taps a re-engagement ad → attribution flows back to that ad campaign separately from a new install.

### Publisher (showing the ad)

The JWS impression must include `eligible-for-re-engagement: true`. Then on tap:

```swift
try await impression.handleTap(reengagementURL: deepLinkURL)
```

The system opens the URL inside the advertised app (deep link) AND records re-engagement.

### Advertised App (receiving re-engagement)

```swift
// In your scene/app delegate URL handler
if let reengagementParam = userActivity.webpageURL?.params["postbackReengagement"] {
    Task {
        try await Postback.updateConversionValue(
            5,
            coarseConversionValue: .medium,
            lockPostback: false,
            conversionTypes: [.reengagement]   // iOS 18+ API
        )
    }
}
```

### Limits

- Apple caps re-engagement: monthly per-app + yearly per-device limits
- Only AAK supports it (SKAN 4's "view-through re-engagement" is much more limited)
- Re-engagement window: 2 days from impression → first update (vs 60 days for installs)
- Add `OptInForReengagementPostbackCopies = true` in Info.plist (already in your AAK block) to receive re-engagement postback copies on your `AttributionCopyEndpoint`

## Common Failure Modes

### 1. "Tier 0 — postback has no source-id, no CV"

**Cause:** Ad creative didn't reach crowd anonymity threshold.

**Fix:** consolidate small campaigns; use shared source IDs across creative variants; let campaigns run longer to accumulate volume.

### 2. "1st postback never arrives"

**Cause:** `updateConversionValue(0)` was never called on first launch — conversion window never opened.

**Fix:** call it unconditionally in `application(_:didFinishLaunchingWithOptions:)` or earliest scene activation.

### 3. "Postback arrives but `did-win = false`"

**Cause:** another ad network won the attribution. Normal — only one wins per install.

**Fix:** nothing to fix; this is correct behavior. Compare to win-rate across networks to evaluate creative effectiveness.

### 4. "MMP shows installs but no SKAN postbacks"

**Cause:** MMP's SKAN postback endpoint not configured in ad network setup, OR `AdNetworkIdentifiers` missing the partner's ID.

**Fix:** check MMP integration page → verify SKAN endpoint URL is registered with each ad partner's dashboard.

### 5. "Conversion values look random / no pattern"

**Cause:** privacy noise injection on Tier 0/1, OR your encoding scheme is too granular for the volume you have.

**Fix:** simplify to coarse 3-bucket encoding until you reach Tier 2 consistently.

### 6. "After SKAN→AAK migration, all CVs arrive as 0 or null"

**Cause:** Common migration regression — team kept calling one API but stopped calling the other:
- Kept `SKAdNetwork.updatePostbackConversionValue` but stopped `Postback.updateConversionValue` → AAK postbacks empty
- Kept `Postback.updateConversionValue` but stopped `SKAdNetwork.updatePostbackConversionValue` → SKAN postbacks empty
- Old SKAN endpoint still configured in MMP but app no longer hits it

**Fix:**
1. Verify both API calls fire on each meaningful event (search codebase for both symbols)
2. Check MMP postback endpoint: SKAN endpoints typically `/skadnetwork/...`, AAK endpoints `/aak/...` — should see traffic on BOTH
3. Use simctl log filter to confirm device emits both: `xcrun simctl spawn booted log stream --predicate 'subsystem CONTAINS "AdAttributionKit" OR subsystem CONTAINS "SKAdNetwork"'`

## Verification

```bash
# Test postback delivery to your AttributionCopyEndpoint
# Apple provides no test mode — but you can monitor server logs after a real install.
# Use Charles Proxy or RunpostbackTest from Apple to validate signature parsing.

# Check that your app actually has AAK enabled:
xcrun simctl spawn booted log stream --predicate 'subsystem CONTAINS "com.apple.AdAttributionKit"'
```

## Related

- `att-timing-and-events.md` — what happens BEFORE postback layer (deterministic)
- `meta-aem-troubleshoot.md` — Meta uses AEM, not standard SKAN; different rules
- `apple-ads-audit.md` — Apple Ads dual attribution specifics
