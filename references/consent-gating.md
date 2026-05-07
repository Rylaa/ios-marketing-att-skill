# Consent Gating — ATT 4-State Handling + Per-SDK Init

Once ATT resolves, every marketing SDK must do something different per state. Skipping this is the #2 source of attribution loss.

## ATT State → SDK Action Matrix

| State | AppsFlyer | Adjust | Meta SDK | Firebase Analytics | AdMob | Crashlytics |
|---|---|---|---|---|---|---|
| `.authorized` | `start()` full after wait config | `initSdk()` full after delay config | (iOS <17 only) `Settings.isAdvertiserTrackingEnabled = true` | Enable only under your analytics/ad consent model | UMP/CMP consent + personalized ads if allowed | `setCrashlyticsCollectionEnabled(true)` (independent) |
| `.denied` | `start()` limited/SKAN mode | `initSdk()` limited/SKAN mode | (iOS <17 only) `Settings.isAdvertiserTrackingEnabled = false`; AEM/S2S path | Enable only for non-tracking first-party analytics use; disable ad personalization/integration as required | UMP/CMP consent + non-personalized/limited ads | unchanged |
| `.notDetermined` | Configure wait first; do not send unmanaged events | Configure ATT wait OR first-session delay first; do not combine both | (iOS <17 only) `Settings.isAdvertiserTrackingEnabled = false`; queue app events | Apply Firebase consent defaults before collection starts | UMP/CMP before ad requests | unchanged |
| `.restricted` | `start()` limited/SKAN mode | `initSdk()` limited/SKAN mode | (iOS <17 only) tracking off | Same as denied | Same as denied | unchanged |

**iOS 17+ note:** On iOS 17+, the Meta SDK reads `ATTrackingManager.trackingAuthorizationStatus` automatically. The `Settings.shared.isAdvertiserTrackingEnabled` setter is deprecated and a no-op. Wrap legacy calls in `if #unavailable(iOS 17) { ... }`.

**Critical:** Crashlytics is largely independent from ATT, but Firebase Analytics is not automatically "ATT-free." Firebase can collect IDFV and may use IDFA when present; Google Ads linking, ad personalization, and remarketing require the appropriate Firebase/Google consent controls in addition to ATT. Treat Firebase Analytics as first-party only when you have disabled ad-use paths and your privacy disclosures match that use.

## Pre-Permission Prompt Pattern (Apple-approved, opt-in lift +15-25%)

Apple allows a custom screen BEFORE the system ATT dialog. Use it. Optimization data shows custom prompts lift opt-in 15-25% vs raw system dialog.

### Required components

1. **Value-prop copy**: explain what user gets if they allow, in plain language
2. **No bait-and-switch**: don't promise things ATT permission doesn't actually unlock
3. **Single CTA**: button labeled "Continue" or "Got it" — NOT "Allow" (Apple rejects "Allow" mimicking system button)
4. **No third option**: do not pre-deny on user's behalf with a "Skip" button (App Review will reject)

### App Review rejection patterns (2024-2026)

Common rejection reasons under Guideline 5.1.2 — avoid all of these:

- **Incentivized opt-in.** Offering rewards, currency, or feature unlocks in exchange for tapping "Allow" → instant reject. The pre-permission screen must be informational only.
- **Two-button pre-permission with "Maybe later" or similar effective-deny.** Even if you don't programmatically deny, giving users a path to skip the system dialog is rejected. Use ONE button leading to the system prompt.
- **Vague third-party language.** "We share with advertising partners" or "third parties" without naming who/why → reject. Be specific or omit.
- **Modal/sheet stacking.** Triggering ATT inside a presented modal that obscures or competes with the system dialog → reject. ATT must fire from a clean view state.
- **Triggering before user interaction.** ATT prompt on cold-start before any user action is allowed BUT increasingly flagged when paired with vague description. Pair with pre-permission screen for safety.

### Example

```swift
struct AttPrePermissionView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 60))
            Text("Help us improve")
                .font(.title.bold())
            Text("On the next screen, iOS will ask if we can measure how you found us. This helps us understand which content brought you here so we can make more of it.\n\nWe never sell your data. You can change this in Settings any time.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Continue") {
                onContinue()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

// Trigger:
AttPrePermissionView {
    ATTrackingManager.requestTrackingAuthorization { status in
        // record status, propagate to SDKs (see next section)
    }
}
```

## Required Info.plist Keys

```xml
<key>NSUserTrackingUsageDescription</key>
<string>This identifier helps us measure which marketing campaigns brought you to the app, so we can make better content. Your data is never sold and you can change this in Settings.</string>
```

App Review hard-rejects vague descriptions ("for advertising", "to track you"). Be specific about the value to the user.

## SDK Initialization — The "Consent Gate" Pattern

**iOS 17+ behavior change:** Apple deprecated the Meta SDK's `Settings.shared.isAdvertiserTrackingEnabled` setter on iOS 17+. The SDK now reads `ATTrackingManager.trackingAuthorizationStatus` directly, so calling the setter is a no-op. Keep the legacy assignments behind `if #unavailable(iOS 17) { ... }` so older OS versions still get the explicit toggle without compiler warnings or wasted runtime work on modern devices.

```swift
@MainActor
final class MarketingStack {
    static let shared = MarketingStack()
    private var initialized = false

    func initializeAfterATT(status: ATTrackingManager.AuthorizationStatus) {
        guard !initialized else { return }
        initialized = true

        switch status {
        case .authorized:
            initFullStack()
        case .denied, .restricted:
            initLimitedStack()
        case .notDetermined:
            // Should not reach here — ATT prompt should have resolved first
            // If it does, treat as denied (safer)
            initLimitedStack()
        @unknown default:
            initLimitedStack()
        }
    }

    private func initFullStack() {
        // AppsFlyer
        AppsFlyerLib.shared().appsFlyerDevKey = "YOUR_DEV_KEY"
        AppsFlyerLib.shared().appleAppID = "1234567890"
        AppsFlyerLib.shared().start()

        // Meta SDK
        if #unavailable(iOS 17) {
            Settings.shared.isAdvertiserTrackingEnabled = true
            Settings.shared.isAdvertiserIDCollectionEnabled = true
        }
        ApplicationDelegate.shared.application(
            UIApplication.shared,
            didFinishLaunchingWithOptions: nil
        )

        // Firebase Analytics (separate analytics/ad consent gate)
        if userConsentedToAnalytics {
            Analytics.setConsent([
                .analyticsStorage: .granted,
                .adStorage: .granted,
                .adUserData: .granted,
                .adPersonalization: .granted
            ])
            Analytics.setAnalyticsCollectionEnabled(true)
        }
    }

    private func initLimitedStack() {
        // AppsFlyer still starts — it auto-falls-back to SKAN mode when ATT denied
        AppsFlyerLib.shared().appsFlyerDevKey = "YOUR_DEV_KEY"
        AppsFlyerLib.shared().appleAppID = "1234567890"
        AppsFlyerLib.shared().start()  // SKAN-only postbacks

        // Meta — disable cross-app tracking, but AEM still works server-side
        if #unavailable(iOS 17) {
            Settings.shared.isAdvertiserTrackingEnabled = false
        }

        // Firebase Analytics (still own consent; keep ad-use disabled if not consented)
        if userConsentedToAnalytics {
            Analytics.setConsent([
                .analyticsStorage: .granted,
                .adStorage: .denied,
                .adUserData: .denied,
                .adPersonalization: .denied
            ])
            Analytics.setAnalyticsCollectionEnabled(true)
        }

        // AdMob: npa=1 is only a request parameter. Use UMP/CMP consent and
        // request limited/non-personalized ads according to the user's choices.
        let request = GADRequest()
        let extras = GADExtras()
        extras.additionalParameters = ["npa": "1"]
        request.register(extras)
    }
}
```

## The Facebook AppEvents Silent-Denied Bug

Meta SDK has a code path where `isAdvertiserTrackingEnabled = false` causes `AppEvents.shared.logEvent()` to **silently drop** the event. No error, no warning. From an observed production incident:

```swift
// ❌ BAD — silent drop on denied users
Settings.shared.isAdvertiserTrackingEnabled = (status == .authorized)
// On iOS 17+ this line is a no-op; the issue is still real because the SDK auto-reads ATT and silently drops
AppEvents.shared.logEvent(.viewedContent)  // dropped if denied, no log
```

Fix: route Meta events through your own analytics layer that forwards eligible events to a backend, then to Meta's Conversions API for App Events when ATT and other applicable privacy consent allow it. The Meta SDK becomes a fallback for ATT-authorized users, not the only path.

```swift
// ✅ GOOD — always send to your backend first
func logMarketingEvent(_ event: MarketingEvent) {
    // 1. Send to your backend (always works)
    BackendClient.shared.logEvent(event)

    // 2. Best-effort to Meta SDK (works only if ATT authorized)
    if ATTrackingManager.trackingAuthorizationStatus == .authorized {
        AppEvents.shared.logEvent(event.metaName, parameters: event.metaParams)
    }
}
```

Backend then forwards to Meta Conversions API for App Events only with the right consent basis. Hashed email, phone, CUID, IP address, device IDs, and other identifiers can still be "tracking" under Apple's ATT policy when linked with third-party data for advertising measurement. Server transport does not bypass ATT.

## App Settings Deep Link

Add a "Privacy" row in your Settings screen so users can find the iOS tracking toggle and your in-app consent controls:

```swift
Button("Tracking Settings") {
    if let url = URL(string: UIApplication.openSettingsURLString) {
        UIApplication.shared.open(url)
    }
}
```

This opens iOS Settings → your app → Allow Tracking toggle.

## Verification

After deploying consent gating:

1. **Fresh install on test device**, decline ATT → verify:
   - AppsFlyer dashboard shows install with `idfa = null` and `att_status = denied`
   - SKAdNetwork postback arrives 24-48h later
   - Meta Events Manager shows install via AEM, not pixel
2. **Fresh install, accept ATT** → verify:
   - AppsFlyer install has real IDFA
   - Meta install fires via SDK
   - Subsequent in-app events all have IDFA attached
3. **Reset Advertising Identifier in Settings** → verify your app handles new IDFA gracefully — **do NOT cache IDFA across launches; read it fresh at event-send time** via `ASIdentifierManager.shared().advertisingIdentifier`. The user can toggle it in iOS Settings any time.

## Related

- `att-timing-and-events.md` — what to do BEFORE ATT resolves
- `meta-aem-troubleshoot.md` — Meta-specific consent + AEM problems
- `pre-launch-checklist.md` — full pre-launch verification
- `adattributionkit-and-skan.md` — non-deterministic fallback path when ATT denied
- `symptom-to-cause.md` — symptom triage table
