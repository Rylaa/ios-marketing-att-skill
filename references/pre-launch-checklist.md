# Pre-Launch Checklist — iOS Marketing Attribution

Walk through this BEFORE first paid UA spend. Each unchecked item is a future "where did our installs go?" support ticket.

## Phase 1 — Info.plist Foundation

```xml
<!-- Required for ATT prompt -->
<key>NSUserTrackingUsageDescription</key>
<string>We measure which marketing brought you here so we can make better content. Your data is never sold and you can change this in Settings.</string>

<!-- Required for SKAdNetwork postbacks -->
<key>SKAdNetworkItems</key>
<array>
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>v9wttpbfk9.skadnetwork</string>
    </dict>
    <!-- Add ALL ad networks you may use; MMPs maintain master lists -->
</array>

<!-- Required for AdAttributionKit (iOS 17.4+) -->
<key>AdAttributionKit</key>
<dict>
    <key>AttributionCopyEndpoint</key>
    <string>https://attribution.yourdomain.com</string>
    <key>OptInForReengagementPostbackCopies</key>
    <true/>
</dict>

<!-- Optional: if your app shows ads (publisher) -->
<key>AdNetworkIdentifiers</key>
<array>
    <string>example.skadnetwork</string>
    <string>example.adattributionkit</string>
</array>
```

- [ ] `NSUserTrackingUsageDescription` present, specific (not vague), under 200 chars
- [ ] `SKAdNetworkItems` populated with full master list (50-100 entries typical)
- [ ] `AdAttributionKit` block present if targeting iOS 17.4+
- [ ] `AttributionCopyEndpoint` HTTPS-only with valid TLS cert
- [ ] If using Apple Search Ads: `AdServices.framework` linked

## Phase 2 — Privacy Manifest (PrivacyInfo.xcprivacy)

Required since iOS 17 for App Store submission. Marketing-relevant entries:

```xml
<dict>
    <key>NSPrivacyTracking</key>
    <true/>

    <key>NSPrivacyTrackingDomains</key>
    <array>
        <string>app.appsflyersdk.com</string>
        <string>app.adjust.com</string>
        <!-- Add all marketing/analytics domains -->
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
- [ ] `NSPrivacyTrackingDomains` includes EVERY marketing/analytics SDK domain
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
adjustConfig?.attConsentWaitingInterval = 120  // max 360s
adjustConfig?.enableFirstSessionDelay()        // method call, not property

Adjust.initSdk(adjustConfig)                   // v5 (v4 used appDidLaunch)

// After ATT prompt resolves:
Adjust.endFirstSessionDelay()
```

- [ ] `attConsentWaitingInterval` set (recommended 120s; max 360s)
- [ ] Adjust SDK v5.x current line; v4.34.0 minimum if cannot upgrade
- [ ] `enableFirstSessionDelay()` called on v5+ (method, not property)
- [ ] `endFirstSessionDelay()` called after ATT prompt
- [ ] Production environment used in production builds

## Phase 5 — ATT Prompt Implementation

- [ ] Pre-permission screen implemented (lifts opt-in 15-25%)
- [ ] Prompt fires AFTER user invests in app (not first frame on cold start, unless using Defense 1+2 from `att-timing-and-events.md`)
- [ ] All marketing SDK init gated behind ATT resolution (see `consent-gating.md`)
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
- [ ] AEM 8-event hierarchy configured in Events Manager
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
4. **TestFlight builds bypass App Tracking Transparency** in some iOS versions. Always test final attribution on App Store Connect TestFlight build, not local dev build.
5. **App Clip vs full app: separate App ID, separate ATT prompt, separate SKAN setup.** Don't conflate.

## Related

- `att-timing-and-events.md` — Phase 5 + 6 deep dive
- `consent-gating.md` — Phase 5 SDK gating patterns
- `adattributionkit-and-skan.md` — Phase 6 deep dive
- `meta-aem-troubleshoot.md` — Phase 7 Meta-specific
- `apple-ads-audit.md` — post-launch ongoing audit
