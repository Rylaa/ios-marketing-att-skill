# Pre-Launch Checklist — iOS Marketing Attribution

Walk through this BEFORE first paid UA spend. Each unchecked item is a future "where did our installs go?" support ticket.

## Phase 1 — Info.plist Foundation

```xml
<!-- Required for ATT prompt -->
<key>NSUserTrackingUsageDescription</key>
<string>We measure which marketing brought you here so we can make better content. Your data is never sold and you can change this in Settings.</string>

<!-- Source/publisher apps that show ads: SKAN ad network IDs. -->
<!-- Advertiser apps: include only when your MMP/ad partners require a current list. -->
<key>SKAdNetworkItems</key>
<array>
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>v9wttpbfk9.skadnetwork</string>
    </dict>
    <!-- Add ALL ad networks you may use; MMPs maintain master lists -->
</array>

<!-- Optional but recommended for SKAN postback COPIES to MMP/your server (top-level key) -->
<!-- ⚠️ Different from AdAttributionKit > AttributionCopyEndpoint below. -->
<!-- ⚠️ ONLY ONE value allowed. Last writer wins → set to MMP OR custom, not both. -->
<key>NSAdvertisingAttributionReportEndpoint</key>
<string>https://adjust-skadnetwork.com/</string>
<!-- Adjust:     https://adjust-skadnetwork.com/        -->
<!-- AppsFlyer:  https://appsflyer-skadnetwork.com/     -->
<!-- Branch:     check Branch's docs                    -->
<!-- Singular:   check Singular's docs                  -->

<!-- Optional but recommended for AdAttributionKit postback copies (iOS 17.4+) -->
<!-- AttributionCopyEndpoint below is AAK-specific and top-level. -->
<key>AttributionCopyEndpoint</key>
<string>https://attribution.yourdomain.com</string>
<key>EligibleForAdAttributionKitReengagementPostbackCopies</key>
<true/>

<!-- Optional: if your app shows ads (publisher) -->
<key>AdNetworkIdentifiers</key>
<array>
    <string>example.skadnetwork</string>
    <string>example.adattributionkit</string>
</array>
```

- [ ] `NSUserTrackingUsageDescription` present, specific (not vague), under 200 chars
- [ ] `SKAdNetworkItems` populated when this app shows ads, or when current MMP/ad partner docs require partner IDs for compatibility
- [ ] `NSAdvertisingAttributionReportEndpoint` set (SKAN postback copies to MMP/your server) — see `adattributionkit-and-skan.md` for provider URL table
  - [ ] Only ONE value present (Apple plist only allows one — the LAST one wins, so a stale custom URL silently breaks MMP postback copies, or vice versa)
  - [ ] If using an MMP: value matches that MMP's published endpoint (Adjust → `https://adjust-skadnetwork.com/`, AppsFlyer → `https://appsflyer-skadnetwork.com/`, Branch/Singular → check their docs)
  - [ ] Without this key: Apple does not send a direct SKAN postback copy to your endpoint; MMP partner forwarding may still exist
- [ ] `AttributionCopyEndpoint` (AAK-specific, top-level — DIFFERENT from `NSAdvertisingAttributionReportEndpoint` above) HTTPS-only with valid TLS cert if you want AAK postback copies
- [ ] `EligibleForAdAttributionKitReengagementPostbackCopies` set only if you are eligible for and want AAK re-engagement postback copies
- [ ] If using Apple Search Ads: `AdServices.framework` linked

## Phase 2 — Privacy Manifest (PrivacyInfo.xcprivacy)

Required-reason API and privacy manifest declarations matter for App Store submission, especially for third-party SDKs on Apple's required-SDK list. Marketing-relevant entries:

```xml
<dict>
    <key>NSPrivacyTracking</key>
    <true/>

    <key>NSPrivacyTrackingDomains</key>
    <array>
        <string>app.appsflyersdk.com</string>
        <string>app.adjust.com</string>
        <!-- Add domains used for tracking; do not dump every analytics endpoint here -->
    </array>

    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>CA92.1</string>
            </array>
        </dict>
        <!-- Add reasons for IDFV access, system boot time, etc. -->
    </array>

    <key>NSPrivacyCollectedDataTypes</key>
    <array>
        <dict>
            <key>NSPrivacyCollectedDataType</key>
            <string>NSPrivacyCollectedDataTypeDeviceID</string>
            <key>NSPrivacyCollectedDataTypeLinked</key>
            <true/>
            <key>NSPrivacyCollectedDataTypeTracking</key>
            <true/>
            <key>NSPrivacyCollectedDataTypePurposes</key>
            <array>
                <string>NSPrivacyCollectedDataTypePurposeAdvertising</string>
            </array>
        </dict>
    </array>
</dict>
```

- [ ] `PrivacyInfo.xcprivacy` exists in app target
- [ ] `NSPrivacyTracking` matches actual ATT prompt presence
- [ ] `NSPrivacyTrackingDomains` includes domains used for tracking when `NSPrivacyTracking` is true
- [ ] `NSPrivacyAccessedAPITypes` declares reasons for: UserDefaults, file timestamp, system boot time, disk space, active keyboards (any SDK uses them)
- [ ] `NSPrivacyCollectedDataTypes` declares all collected types with purpose
- [ ] Dependent SDKs each have their own `PrivacyInfo.xcprivacy` (Apple now requires this for SDKs too)

#### Required-Reason API Codes (the ones App Review actually checks)

Marketing SDKs (AppsFlyer, Adjust, Branch, Singular, Meta) all touch these APIs. Missing reason codes → App Store rejection with `ITMS-91053: Missing API declaration`.

| Category | Common reason codes | When to use |
|---|---|---|
| `NSPrivacyAccessedAPICategoryUserDefaults` | `CA92.1`, `1C8F.1`, `C56D.1`, `AC6B.1` | All MMP SDKs (store install state) |
| `NSPrivacyAccessedAPICategoryFileTimestamp` | `0A2A.1`, `3B52.1`, `C617.1`, `DDA9.1` | Most analytics SDKs (cache freshness) |
| `NSPrivacyAccessedAPICategorySystemBootTime` | `35F9.1`, `8FFB.1`, `3D61.1` | Marketing SDKs computing session age |
| `NSPrivacyAccessedAPICategoryDiskSpace` | `85F4.1`, `E174.1`, `7D9E.1`, `B728.1` | SDKs that pre-flight cache writes |
| `NSPrivacyAccessedAPICategoryActiveKeyboards` | `54BD.1`, `3EC4.1` | Locale-aware SDKs |

Apple's full reference: https://developer.apple.com/documentation/bundleresources/privacy_manifest_files/describing_use_of_required_reason_api

## Phase 3 — App Store Connect

- [ ] App Privacy section filled out matching `PrivacyInfo.xcprivacy`
- [ ] App listed in correct Meta Business Manager + ad accounts
- [ ] Apple Search Ads campaigns configured if using
- [ ] App ID verified in MMP dashboard (Adjust requires this; AppsFlyer auto-detects)

## Phase 4 — MMP SDK Integration

### AppsFlyer

```swift
// Config BEFORE start
AppsFlyerLib.shared().appsFlyerDevKey = "YOUR_DEV_KEY"
AppsFlyerLib.shared().appleAppID = "1234567890"
AppsFlyerLib.shared().waitForATTUserAuthorization(timeoutInterval: 60)
AppsFlyerLib.shared().isDebug = false  // true only in dev

// CUID if using
if let userId = currentUserId {
    AppsFlyerLib.shared().customerUserID = userId
}

// Start last
AppsFlyerLib.shared().start()
```

- [ ] `waitForATTUserAuthorization` set BEFORE `start()`
- [ ] Dev key + App ID correct
- [ ] CUID set BEFORE `start()` if needed
- [ ] `isDebug = false` in production builds
- [ ] Conversion data listener implemented for deferred deep linking

### Adjust (v5 API)

```swift
import AdjustSdk

let adjustConfig = ADJConfig(
    appToken: "YOUR_TOKEN",
    environment: ADJEnvironmentProduction
)
// Option A:
adjustConfig?.attConsentWaitingInterval = 120  // max 360s

// Option B (SDK 5.3.0+): use instead of attConsentWaitingInterval
// adjustConfig?.enableFirstSessionDelay()      // method call, not property

Adjust.initSdk(adjustConfig)                   // v5 (v4 used appDidLaunch)

// If Option B is used, after ATT prompt or your own consent/data enrichment resolves:
// Adjust.endFirstSessionDelay()
```

- [ ] Choose exactly one Adjust delay mechanism: `attConsentWaitingInterval` OR `enableFirstSessionDelay()` (first-session delay ignores ATT waiting interval)
- [ ] Adjust SDK v5.x current line; v4.34.0 minimum if cannot upgrade
- [ ] If using first-session delay: SDK 5.3.0+ and `endFirstSessionDelay()` called after ATT prompt or consent/data enrichment
- [ ] Production environment used in production builds

## Phase 5 — ATT Prompt Implementation

- [ ] Pre-permission screen implemented (lifts opt-in 15-25%)
- [ ] Prompt fires AFTER user invests in app (not first frame on cold start, unless using Defense 1+2 from `att-timing-and-events.md`)
- [ ] Marketing SDK init and event sending follow each SDK's ATT wait/consent model; unmanaged event pipes are gated behind ATT/privacy resolution (see `consent-gating.md`)
- [ ] Settings deep-link added so users can change choice later
- [ ] No "Allow"/"Deny" custom buttons that mimic system dialog (App Review rejects)
- [ ] Test: install on device with iOS 14.5+, accept → check IDFA non-zero
- [ ] Test: install on device, deny → check IDFA zero, SKAN postback still arrives

## Phase 6 — Conversion Value Mapping

- [ ] Conversion value encoding chosen (funnel / revenue / hybrid — see `adattributionkit-and-skan.md`)
- [ ] First `updateConversionValue(0)` called on app launch (opens window)
- [ ] CV updates wired to key events (signup, purchase, trial start, etc.)
- [ ] CV values mapped in MMP dashboard so postbacks decode to readable funnel steps
- [ ] Lock postback configured for high-value events (purchase, sub conversion)

## Phase 7 — Per-Channel Setup

### Meta App Install (if using)

- [ ] App added to Meta Business Manager
- [ ] App associated with ad account (Business Settings → Apps → Assigned Assets)
- [ ] Domain verified (Brand Safety → Domains)
- [ ] AEM event sharing/toggle and event mapping configured in Meta/MMP; no legacy event-priority hierarchy required
- [ ] AEM toggle visible in Ads Manager when creating campaign
- [ ] Test: real device install → event appears in Meta Events Manager Test Events tab within 30s

### Google App Campaigns (if using)

- [ ] Firebase project linked to Google Ads
- [ ] Firebase events imported into Google Ads conversions
- [ ] SKAdNetwork conversion value mapping configured in Firebase
- [ ] Test: install via test ad → conversion appears in Google Ads within 24h

### TikTok / Snap / etc.

- [ ] SDK or MMP forwarding configured per platform docs
- [ ] SKAN endpoint URL registered in each platform's dashboard

## Phase 8 — Deep Linking

- [ ] `apple-app-site-association` (AASA) file deployed at `https://yourdomain.com/.well-known/apple-app-site-association`
- [ ] AASA validated via Branch.io's tool: https://branch.io/resources/aasa-validator/ (Apple deprecated their standalone validator; alternative: Xcode → Devices → Universal Links)
- [ ] Universal Links handler implemented in `application(_:continue:restorationHandler:)`
- [ ] Deferred deep link via MMP (AppsFlyer OneLink / Adjust Deep Link / Branch)
- [ ] Test: paste link from Notes app → opens app correctly (NOT Safari)
- [ ] Test: uninstall app → click link → install → app opens to correct content (deferred deep link working)

## Phase 9 — Verification (Day -7 Before Launch)

- [ ] Run `scripts/diagnose.sh` — all checks PASS
- [ ] Real-device install: install attributed within 30 mins in MMP dashboard
- [ ] In-app event flow: each key event appears in MMP raw data within 5 mins
- [ ] SKAN postback: arrives in MMP within 24-48h
- [ ] AAK postback: arrives at your `AttributionCopyEndpoint` server
- [ ] Meta Test Events: events appear with green checkmark
- [ ] No "verification error" warnings in any platform dashboard
- [ ] ATT prompt fires correctly on device (not stuck behind capture-protection or modal stacking)

## Phase 10 — Day-1 Monitoring

- [ ] MMP dashboard "Organic" share is <30% (red flag if higher — points to attribution loss)
- [ ] Each ad partner shows installs matching their dashboard ±10%
- [ ] ATT opt-in rate observed and recorded as baseline
- [ ] First conversion value postbacks arriving as expected
- [ ] No spike in `idfa = null` installs from a specific channel (would indicate that channel's tracking broken)

## Common Last-Minute Gotchas

1. **DevKey/AppToken in wrong environment.** Sandbox vs production keys are different. Dev key in prod build = no data.
2. **Plugin/SDK version mismatch.** RN/Flutter/Expo plugin versions can lag native SDK. Check plugin's native dependency version.
3. **PrivacyInfo not bundled in app target.** Drag the file in Xcode → ensure target membership ticked.
4. **TestFlight/local builds do not exercise real paid attribution paths.** Use MMP test tools for smoke tests, then validate final attribution on production App Store traffic.
5. **App Clip vs full app: separate App ID, separate ATT prompt, separate SKAN setup.** Don't conflate.

## Related

- `att-timing-and-events.md` — Phase 5 + 6 deep dive
- `consent-gating.md` — Phase 5 SDK gating patterns
- `adattributionkit-and-skan.md` — Phase 6 deep dive
- `meta-aem-troubleshoot.md` — Phase 7 Meta-specific
- `apple-ads-audit.md` — post-launch ongoing audit
