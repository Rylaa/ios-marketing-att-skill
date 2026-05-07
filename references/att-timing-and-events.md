# ATT Timing + Event Gap (MMP Install/Session vs trackEvent)

The single most common cause of "installs going Organic" on iOS post-14.5.

## The Core Bug Pattern

```
App launch (T=0)
│
├─ T=0    AppDelegate.didFinishLaunching
│         AppsFlyerLib.shared().start()  ← install payload SENT NOW
│         IDFA = 00000000-0000-0000-0000-000000000000  (ATT not granted yet)
│         → MMP records install with no IDFA
│         → Marked "Organic" forever (no re-attribution path)
│
├─ T=2s   Splash screen
│         Adjust.trackEvent("splash_view")  ← event SENT NOW
│         Same problem: no IDFA → Organic event
│
├─ T=8s   Onboarding completes
│         ATTrackingManager.requestTrackingAuthorization { status in ... }
│         User taps "Allow" at T=10s
│         status = .authorized
│         IDFA now real
│
└─ T=10s+ Now subsequent events have IDFA, but install + early events
          are already sealed as Organic. Permanent attribution loss.
```

## Two Defenses, Both Required

### Defense 1: MMP install/session wait interval

Both Adjust and AppsFlyer support holding the install/first-session payload until ATT response or a max wait.

#### Adjust v5 (current, 2025-2026 — strongly recommended)

```swift
import AdjustSdk

let adjustConfig = ADJConfig(
    appToken: "YOUR_TOKEN",
    environment: ADJEnvironmentProduction
)
adjustConfig?.attConsentWaitingInterval = 120  // seconds, max 360 (Adjust iOS native SDK)
adjustConfig?.enableFirstSessionDelay()        // METHOD CALL — delays entire first session

Adjust.initSdk(adjustConfig)                   // v5 init (NOT appDidLaunch — that's v4)

// After ATT prompt resolves, explicitly resume:
Adjust.endFirstSessionDelay()
```

#### Adjust v4 (legacy — only if you cannot upgrade)

```swift
import Adjust

let config = ADJConfig(
    appToken: "YOUR_TOKEN",
    environment: ADJEnvironmentProduction
)
config?.setAttConsentWaitingInterval(120)  // max 360s
Adjust.appDidLaunch(config)                // v4 init API
```

#### AppsFlyer

AppsFlyer auto-buffers when you set:

```swift
AppsFlyerLib.shared().waitForATTUserAuthorization(timeoutInterval: 60)
```

Then:

```swift
AppsFlyerLib.shared().start()  // Will not actually send until ATT resolves OR timeout hits
```

Recommended timeout: **60 seconds** (AppsFlyer official). Longer risks losing the session.

### Defense 2: Don't fire trackEvent before ATT response

`attConsentWaitingInterval` (Adjust) and `waitForATTUserAuthorization` (AppsFlyer) **only buffer the install/session payload**. Arbitrary `trackEvent` calls bypass the buffer and ship immediately.

This is the bug pattern observed in production iOS apps:

```swift
// YourApp/Features/Splash/SplashView.swift:39
// ❌ BAD — fires immediately, ATT may not be resolved yet
Adjust.trackEvent(ADJEvent(eventToken: "pvl5b6"))

// ✅ FIX — gate behind ATT resolution
Task {
    await AttResolver.shared.waitForResolution()  // your wrapper
    Adjust.trackEvent(ADJEvent(eventToken: "pvl5b6"))
}
```

#### Wrapper Pattern

```swift
@MainActor
final class AttResolver {
    static let shared = AttResolver()
    private var continuations: [CheckedContinuation<ATTrackingManager.AuthorizationStatus, Never>] = []
    private var resolved: ATTrackingManager.AuthorizationStatus?

    func waitForResolution() async -> ATTrackingManager.AuthorizationStatus {
        if let resolved { return resolved }
        return await withCheckedContinuation { continuations.append($0) }
    }

    func recordResolution(_ status: ATTrackingManager.AuthorizationStatus) {
        resolved = status
        continuations.forEach { $0.resume(returning: status) }
        continuations.removeAll()
    }
}

// In your ATT prompt code:
ATTrackingManager.requestTrackingAuthorization { status in
    Task { @MainActor in
        AttResolver.shared.recordResolution(status)
    }
}
```

Now any `trackEvent` call site can `await AttResolver.shared.waitForResolution()` before firing.

## When to Show the ATT Prompt

Apple guideline: any time after `applicationDidBecomeActive`, app must be in `.active` state. Best practice for marketing:

| Strategy | Pro | Con |
|---|---|---|
| **Cold-start, first screen** | Maximum data window | Lower opt-in (~25%) — user not invested |
| **After 1st value moment** (first useful action) | Higher opt-in (~40-50%) | Delayed; some events fire pre-resolution |
| **End of onboarding** | Highest opt-in for sub apps (~50-60%) | Long delay risks SKAN window edge cases |
| **Pre-paywall** (subscription apps) | Highest LTV correlation | Late; many events lost to Organic |

For most apps **end-of-onboarding** is optimal IF you implement Defense 1 + 2 properly. Without them, **cold-start prompt is safer** (less time for events to leak with zero IDFA).

## Capture-Protection Silent-Defer Bug

If your app uses iOS 17+ ScreenCaptureKit / `isCaptured` to defer the ATT prompt during screen recording, beware:

```swift
// ❌ BAD — if user re-installs and keychain residue persists, isCaptured can latch true
if !UIScreen.main.isCaptured {
    ATTrackingManager.requestTrackingAuthorization { ... }
}
// → Prompt never shows for affected users
// → Adjust 120s timeout fires
// → Install attributed as Organic forever
```

Fix: add a hard timeout that forces the prompt regardless of capture state after N seconds, OR move capture-defer logic to a setting the user can toggle.

## Diagnostic Checklist

When attribution looks broken, check in this order:

1. **Is `attConsentWaitingInterval` (Adjust) or `waitForATTUserAuthorization` (AppsFlyer) actually set?** Search the codebase for these symbols. Absent = root cause found.
2. **Is `start()` / `appDidLaunch` called BEFORE the wait config is set?** Order matters. Config first, then start.
3. **Are there `trackEvent` calls between `start()` and the ATT prompt completion?** Grep for `trackEvent`, `logEvent`, `AppEvents.shared.logEvent`. Each is a leak point.
4. **Does the ATT prompt actually fire?** Add a log on every callback path. Capture-protection or modal stacking can silently swallow it.
5. **Is the wait interval long enough to cover your onboarding?** If onboarding takes 90s and interval is 60s, install ships before prompt.
6. **Are you on Adjust v5.x (recommended) or v4.34.0+ minimum / AppsFlyer 6.14.0+ for full SKAN 4 + AAK?** Older versions miss the wait APIs and modern postback support.

## React Native + Expo

For RN+Expo projects (common in 2026 stacks), the Swift snippets above don't apply directly. Use the JS bridges instead:

```typescript
// AppsFlyer — react-native-appsflyer
import appsFlyer from 'react-native-appsflyer'

appsFlyer.initSdk({
  devKey: 'YOUR_DEV_KEY',
  appId: '1234567890',
  isDebug: __DEV__,
  onInstallConversionDataListener: true,
  timeToWaitForATTUserAuthorization: 60,  // ← equivalent of waitForATTUserAuthorization
}, console.log, console.error)
```

```typescript
// Adjust — react-native-adjust v5+
import { Adjust, AdjustConfig } from 'react-native-adjust'

const adjustConfig = new AdjustConfig('YOUR_TOKEN', AdjustConfig.EnvironmentProduction)
adjustConfig.setAttConsentWaitingInterval(120)
adjustConfig.enableFirstSessionDelay()  // delays first session until ATT resolves

Adjust.initSdk(adjustConfig)

// After ATT prompt resolves:
Adjust.endFirstSessionDelay()
```

```typescript
// ATT prompt via expo-tracking-transparency (Expo dev client / standalone build only)
import { requestTrackingPermissionsAsync } from 'expo-tracking-transparency'

const { status } = await requestTrackingPermissionsAsync()
// status: 'undetermined' | 'denied' | 'authorized' | 'restricted'

// Now resume Adjust + signal AppsFlyer
Adjust.endFirstSessionDelay()
```

Notes:
- Expo Go does NOT support ATT — must use dev client or standalone build
- `react-native-adjust` package version must match the underlying native Adjust SDK version
- `react-native-appsflyer` plugin in `app.config.ts` is preferred over manual Podfile editing on Expo

## Verification

Use the script in `scripts/diagnose.sh` to grep your project for the common anti-patterns. Expected output if healthy:

```
✓ attConsentWaitingInterval found in 1 location
✓ start() called AFTER waitFor* config
✓ no trackEvent calls outside guard wrapper
✓ ATT prompt has timeout fallback
```

## Related References

- `consent-gating.md` — what to do per ATT state once resolved
- `meta-aem-troubleshoot.md` — Meta-specific event delivery problems
- `adattributionkit-and-skan.md` — postback layer that compensates when ATT denied
- `symptom-to-cause.md` — broader triage table when symptom is unclear
