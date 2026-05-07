# Apple Ads + MMP Audit (ASA Health Score Framework)

Condensed audit framework derived from `AgriciDaniel/claude-ads → ads-apple`. Use when user asks "audit our Apple Ads setup" or "how healthy is our ASA?"

For deep campaign-strategy work (keyword expansion, bid strategy tuning, CPP testing), **delegate to the upstream `ads-apple` skill** — that's its domain. This file focuses on the **ATT/MMP/measurement plumbing** intersection.

## Apple Ads Health Score (0-100)

### Weighted Categories

| Category | Weight |
|---|---|
| Campaign Structure | 25% |
| Bid Health | 20% |
| Custom Product Pages (CPP) | 15% |
| Attribution & MMP | 15% ← **THIS SKILL'S FOCUS** |
| Budget Pacing | 10% |
| TAP Coverage | 10% |
| Goal KPI Assessment | 5% |

This skill specifically owns the **Attribution & MMP** category. Other categories: delegate to `ads-apple`.

## Attribution & MMP Checklist (15% of total score)

### Core Integration Checks (PASS/WARN/FAIL each)

1. **MMP integrated with Apple Ads attribution paths**
   - PASS: MMP dashboard shows Apple Ads as configured partner, with AdServices and SKAN/AAK settings enabled where the MMP supports them
   - WARN: configured but no postbacks in last 7 days (volume issue OR mis-configured)
   - FAIL: Apple Ads not registered as partner

2. **Apple Ads connected as partner in MMP**
   - Go to: AppsFlyer/Adjust/Branch dashboard → Integrated Partners → Apple Ads → verify enabled
   - Check: campaign-level data flows back (not just install count)

3. **In-app events imported/forwarded where your reporting stack needs them**
   - Useful for MMP reporting, downstream analytics, and non-Apple ad platforms
   - Do not claim Apple Ads Maximize Conversions optimizes to post-install events or ROAS; the current Maximize Conversions product optimizes tap-through installs with target CPA

4. **SKAN/AdAttributionKit support checked**
   - Apple Ads attribution may arrive through AdServices and privacy-preserving postbacks depending on current Apple/MMP support
   - MMPs deduplicate overlapping paths; do not require both to appear in raw logs for every install

5. **SKAdNetwork conversion values configured**
   - Conversion value mapping defined in MMP dashboard
   - Maps user actions → CV bucket (see `adattributionkit-and-skan.md` for encoding)

6. **ATT opt-in rate monitored**
   - Track in MMP: "ATT authorized" % of installs
   - Below 25% = investigate prompt design (use `consent-gating.md`)
   - Below 15% = critical, prompt may have UX issue

7. **Privacy threshold considerations**
   - Track: % of installs receiving full postback vs. null postback
   - High null rate = volume too low for crowd anonymity tier

### Attribution Windows

8. **Default Apple Ads attribution: 30-day click, 1-day view**
   - Appropriate for most install goals
   - For re-engagement campaigns: verify the current Apple Ads/AAK click and view windows in your MMP before changing defaults

9. **WWDC 2025 features**
   - Configurable attribution windows: enabled?
   - Overlapping re-engagement windows: relevant if running re-engagement?
   - Country codes in postbacks: enabled in MMP?

## Sample Audit Output

```markdown
## Apple Ads — Attribution & MMP Audit

**Score: 11/15 (73%)**

### PASS
- ✅ MMP integrated with Apple Ads attribution paths (AppsFlyer)
- ✅ Apple Ads partner configured in AppsFlyer
- ✅ 5 in-app events available in MMP reporting (install, signup, trial_start, sub_renewed, purchase)
- ✅ SKAdNetwork conversion values mapped (revenue-bucket encoding)
- ✅ Default attribution windows in use (30d click, 1d view)

### WARNING
- ⚠️ ATT opt-in rate at 18% (below 25% target). Likely cause: ATT prompt fires on cold start without value-prop screen. Action: implement pre-permission screen (see consent-gating.md).
- ⚠️ ~12% of installs receive null postbacks (Tier 0). Likely cause: campaign volume too low. Action: consolidate creative groupings to climb crowd anonymity tier.

### FAIL
- ❌ Apple Ads privacy-preserving postback setup incomplete. Action: verify current MMP Apple Ads partner settings, conversion mapping, and any required postback-copy endpoints/partner ID lists.

### Top Action (this week)
1. Fix Apple Ads partner/postback setup in the MMP → improve privacy-preserving attribution coverage
2. Implement ATT pre-permission screen → estimated +15-25% opt-in lift
3. Consolidate 8 small Search Match campaigns into 2 larger ones → climb to Tier 2/3 postbacks
```

## Quick Fixes by Symptom

| Symptom | Likely Cause | Fix Reference |
|---|---|---|
| Apple Ads in MMP shows 0 installs but Apple Ads dashboard shows installs | Partner not enabled OR postback URL wrong | MMP → Integrated Partners → Apple Ads → verify endpoint |
| Apple Ads installs OK but no in-app events in your MMP reports | Event mapping/import not configured | MMP → Apple Ads / reporting settings → map events as needed |
| All Tier 0 postbacks | Volume too low | Consolidate campaigns; let creative variants share source ID |
| MMP shows install double-count for Apple Ads | Overlapping Apple Ads paths or partner settings | Most MMPs auto-deduplicate; check Apple Ads partner settings |
| ATT opt-in <15% | Bad prompt design | See `consent-gating.md` pre-permission section |
| In-app events go "Organic" in MMP | ATT timing bug | See `att-timing-and-events.md` |
| 80% Apple Ads installs show as Organic | AdServices API token not implemented OR not forwarded to MMP | See "AdServices API" section below |

## AdServices API (Apple Ads Deterministic Path)

The MOST common cause of "80% Apple Ads installs go Organic" is missing Apple Ads partner/AdServices integration. AdServices is a token-based, IDFA-independent attribution path. It is not an ATT bypass for third-party tracking; ATT can still affect available detail and other SDK signals.

### How it works

1. App fetches a one-time attribution token via `AAAttribution.attributionToken()` on first launch
2. App POSTs token to `https://api-adservices.apple.com/api/v1/` (or via MMP's S2S)
3. Apple returns campaign metadata (campaign ID, ad group, keyword, country, etc.)
4. MMP stores attribution → Apple Ads install no longer "Organic"

### Implementation

```swift
import AdServices

func reportAppleAdsAttribution() async {
    do {
        let token = try AAAttribution.attributionToken()

        // Option A: send through your MMP if their current SDK/S2S API requires it.
        // Many current iOS SDKs auto-handle AdServices when the framework is linked
        // and the Apple Ads partner integration is enabled. Check your MMP docs.

        // Option B: call Apple directly (if not using MMP)
        var request = URLRequest(url: URL(string: "https://api-adservices.apple.com/api/v1/")!)
        request.httpMethod = "POST"
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.httpBody = token.data(using: .utf8)
        let (data, _) = try await URLSession.shared.data(for: request)
        // data = JSON with campaignId, adGroupId, keyword, etc.
    } catch {
        print("AAAttribution failed: \(error)")
    }
}
```

### Required Info.plist + framework

- Link `AdServices.framework` (Build Phases → Link Binary With Libraries)
- No Info.plist key needed
- Token expires within 24 hours of generation — fetch on first launch and forward immediately

### Verification

In MMP raw data, an Apple Ads install with proper AdServices integration shows:
- `media_source: Apple Search Ads` (NOT "Organic")
- `campaign: <real-name>` (NOT "None")
- `ad_unit: <ad-group-name>`
- `keyword: <keyword-or-Search-Match>`

If any of these is null/None → token or Apple Ads partner data is not reaching the MMP. Check the MMP's current AdServices/Apple Ads integration before adding custom token forwarding.

### MMP-specific endpoints

| MMP | Current guidance |
|---|---|
| AppsFlyer | Link `AdServices.framework`; Apple Ads attribution collection is SDK/partner controlled unless disabled. |
| Adjust | Link `AdServices.framework`; SDK + Apple Ads integration handle attribution. `needsCost` is about cost fields, not token forwarding. |
| Branch | Use Branch's current SDK or S2S Apple Ads attribution-token support. |
| Singular | Use Singular's current SDK or S2S `attribution_token` support. |

## Maximize Conversions + CPP Updates (2025-2026 Apple Ads Changes)

Two changes the audit framework must account for:

1. **Maximize Conversions bidding (GA February 26, 2026)** — AI auto-bidder using Search Match. Target CPA replaces deprecated CPA Cap. **Limitation:** only optimizes for installs, NOT post-install events (no trial/sub/ROAS optimization yet). When auditing: if account uses Maximize Conversions, flag that downstream MMP event forwarding does not yet drive bid changes.

2. **Custom Product Pages (CPP) cap raised to 70 (Oct 2025)** — and **Creative Sets fully deprecated**. CPPs are now sole ad-variation mechanism. Audit check: if user mentions "Creative Sets", correct to CPPs.

## Required Data to Request from User Before Audit

If user asks for audit but hasn't provided data, ask for:

- MMP being used (AppsFlyer / Adjust / Branch / Singular)
- Apple Ads campaign list with: spend, installs, CPT, TTR, CVR (last 30 days)
- ATT opt-in rate (from MMP dashboard)
- % of installs with non-zero postbacks (from MMP)
- Whether SKAN/AdAttributionKit postback support and copy endpoints are configured (Info.plist + MMP partner settings)
- Active placement types (Search Results / Today / Search Tab / Product Pages)
- Target CPI / CPA + app category
- Countries/regions active

## Delegate Beyond MMP/ATT Scope

If audit reveals issues outside attribution plumbing:
- Campaign structure / keyword strategy / CPP design → `ads-apple` skill
- Deep link routing → `mobile-deep-linking-specialist` skill
- App Store review concerns / privacy manifest → `app-store-review` skill
- Multi-channel UA strategy → `app-ads` skill

## Related

- `att-timing-and-events.md` — fix root-cause of MMP attribution loss
- `consent-gating.md` — improve ATT opt-in for better Apple Ads modeling
- `adattributionkit-and-skan.md` — postback layer details
- `pre-launch-checklist.md` Phase 7 — initial Apple Search Ads setup
- `symptom-to-cause.md` — broader cross-channel triage
