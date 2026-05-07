---
name: marketing-att-pipeline
description: >-
  Use when integrating, debugging, or auditing iOS marketing channel attribution
  under App Tracking Transparency (ATT). Covers AppsFlyer / Adjust / Branch /
  Singular SDK init order, ATT prompt timing, attConsentWaitingInterval
  semantics, trackEvent gap, Meta Aggregated Event Measurement (AEM) + ATE
  verification, SKAdNetwork v3/v4 + AdAttributionKit (AAK) dual attribution,
  conversion value mapping, Facebook AppEvents consent gating, Apple Search Ads
  / Google App Campaigns / Meta App Install / TikTok App Install measurement,
  privacy manifests, and MMP postback troubleshooting. Activate on keywords:
  ATT, IDFA, ATTrackingManager, NSUserTrackingUsageDescription, MMP,
  AppsFlyerLib, Adjust, Branch, Singular, SKAdNetwork, SKAN, AdAttributionKit,
  AAK, conversion value, postback, install attribution, Meta AEM, ATE,
  Aggregated Event Measurement, App Tracking Transparency, attConsentWaiting,
  organic install surge, "installs missing", "events going organic", privacy
  manifest, PrivacyInfo.xcprivacy, Apple Ads, Apple Search Ads, ASA, Google
  App Campaigns, GAC, UAC, Firebase iOS attribution, conversion window, dual
  attribution. Use proactively whenever an iOS app integrates a marketing SDK
  (AppsFlyer, Adjust, Branch, Singular, Meta SDK, Firebase) or when debugging
  attribution loss, IDFA-zero issues, or post-iOS-14.5 measurement gaps.
license: MIT
metadata:
  author: Rylaa
  version: "1.1.0"
  created: "2026-05-07"
  updated: "2026-05-07"
  domain: mobile-marketing
  sources:
    - AgriciDaniel/claude-ads (ads-apple)
    - dpearson2699/swift-ios-skills (adattributionkit)
    - mukul975/Privacy-Data-Protection-Skills (managing-mobile-app-consent)
    - Anonymized production incident analysis
---

# Marketing + ATT Pipeline (iOS)

End-to-end skill for iOS marketing channel attribution under Apple's App Tracking Transparency. Merges audit framework (ads-apple), AdAttributionKit reference (adattributionkit), and SDK consent gating (managing-mobile-app-consent), plus anonymized production incident learnings.

## When To Use This Skill

Activate this skill when ANY of the following is true:

1. New iOS project integrating a marketing SDK (AppsFlyer, Adjust, Branch, Singular, Meta, Firebase Analytics, AdMob).
2. Existing iOS app showing attribution loss after iOS 14.5: organic install surge, MMP dashboard "Organic" share rising, Meta AEM events missing, conversion value postbacks empty.
3. ATT prompt timing question (when to show, what wait interval, app-launch race conditions).
4. SKAdNetwork ↔ AdAttributionKit migration or dual-attribution setup.
5. Pre-launch checklist for an iOS app that runs paid UA.
6. Audit request: "is our iOS attribution stack healthy?"

If the user mentions any keyword from the description's keyword list, this skill should fire.

## Workflow / Operating Sequence

For any task, follow `WORKFLOW.md` — it defines the standard 5-stage flow (CONTEXT → ROUTE → DIAGNOSE → ACT → VERIFY) and which reference files to consume in what order. Read it FIRST before diving into the decision tree below.

## Decision Tree (Entry Point)

```
What is the user asking?
│
├─ "Install / event attribution missing or going Organic"
│   └─→ references/att-timing-and-events.md
│       Cover: SDK init order, attConsentWaitingInterval semantics,
│       trackEvent vs install payload gap, capture-protection silent-defer,
│       Adjust v5 enableFirstSessionDelay, Facebook AppEvents denied path
│
├─ "Meta AEM not visible / ATE verification error / Meta + AppsFlyer setup"
│   └─→ references/meta-aem-troubleshoot.md
│       Cover: domain verification, app status prerequisites, CUID role,
│       AEM 8-event prioritization, ATE postback debug, RN/Expo gotchas
│
├─ "ATT prompt design / consent flow / SDK gating"
│   └─→ references/consent-gating.md
│       Cover: ATT 4-state matrix, pre-permission prompt pattern,
│       NSUserTrackingUsageDescription wording, per-SDK init pattern
│       (AppsFlyer, AdMob, Firebase, Crashlytics, Meta), Android parity
│
├─ "AdAttributionKit / SKAdNetwork conversion values / postbacks"
│   └─→ references/adattributionkit-and-skan.md
│       Cover: 3 conversion windows, tier 0-3 postback granularity,
│       fine vs coarse values, lockPostback timing, AttributionCopyEndpoint,
│       dual attribution since Apr 2025, Apple Ads AAK + AdServices API
│
├─ "Audit our Apple Ads + MMP setup" / "ASA health check"
│   └─→ references/apple-ads-audit.md (uses ads-apple framework)
│       Cover: campaign structure, bid health, CPP, MMP integration check,
│       AdAttributionKit dual attribution, ASA Health Score 0-100
│
├─ "Pre-launch / new project setup"
│   └─→ references/pre-launch-checklist.md
│       Cover: Info.plist keys, ATT description, SKAdNetworkItems,
│       PrivacyInfo.xcprivacy, AdNetworkIdentifiers, AASA file,
│       MMP DevKey/AppID config, conversion value mapping, test postbacks
│
└─ "I don't know what's wrong, attribution feels off"
    └─→ scripts/diagnose.sh + references/symptom-to-cause.md
        Cover: symptom → likely cause → which reference to read next
```

## Core Concepts (Read Before Diving)

### ATT 4-State Behavior Matrix

| State | Meaning | IDFA | MMP Action | Marketing SDK Action |
|---|---|---|---|---|
| `.notDetermined` | User not asked yet | All zeros | **Buffer install/session payload** (do NOT send yet) | Init in deferred mode; queue events |
| `.authorized` | User allowed | Real IDFA | Send full payload with IDFA | Enable user-level tracking |
| `.denied` | User declined | All zeros | Send aggregate-only via SKAN/AAK | Switch to SKAdNetwork-only mode; NO trackEvent for user-level |
| `.restricted` | MDM/parental block | All zeros | **Do NOT prompt** (`requestTrackingAuthorization` will fail silently); use SKAN | SKAN-only mode |

**Critical:** `.notDetermined` is the dangerous state. If your MMP SDK fires `start()` here without a wait interval, install payload goes out with zero IDFA → MMP can never re-attribute it later → permanent "Organic" misclassification.

### The Three Layers of iOS Attribution (post iOS 14.5)

```
┌─────────────────────────────────────────────────────────┐
│ Layer 1: Deterministic (IDFA-based)                     │
│  Requires ATT .authorized                               │
│  ~25-40% global opt-in (varies by category)             │
│  → Full user-level events to AppsFlyer/Adjust/Branch    │
├─────────────────────────────────────────────────────────┤
│ Layer 2: SKAdNetwork (SKAN v3/v4) + AdAttributionKit    │
│  Privacy-preserving, no user-level data                 │
│  Apple-mediated postbacks 24-48h delay (1st window)     │
│  Conversion values: fine 0-63 OR coarse low/medium/high │
│  → MMP receives postback, maps CV → revenue/funnel step │
├─────────────────────────────────────────────────────────┤
│ Layer 3: Probabilistic / modeled (MMP-side)             │
│  Statistical fingerprinting where allowed by Apple      │
│  Modeled conversions for non-consented users            │
└─────────────────────────────────────────────────────────┘
```

A healthy stack uses **all three** simultaneously. If only one is wired, you're losing 30-70% of attribution coverage.

### Two Most Common Production Failures

1. **The `attConsentWaitingInterval` Trap.** MMP SDKs (Adjust, AppsFlyer) provide a wait interval that delays the **install/first-session payload** until ATT response arrives. But it does NOT delay arbitrary `trackEvent` calls. Splash, onboarding, first-app-open events fired before ATT response go out with zero IDFA → permanent Organic. Fix in `references/att-timing-and-events.md`.

2. **Silent Consent-Denied Paths.** Marketing SDKs often have a code path where `requestTrackingAuthorization` denied/notDetermined results in early-return without logging. Looks like "everything works" until you check the dashboard and see a 50% drop in events. Fix in `references/consent-gating.md`.

## Channel-Specific Quick Reference

| Channel | iOS Attribution Mechanism | ATT Dependency | Key SDK |
|---|---|---|---|
| **Apple Ads (ASA)** | AAK + AdServices API (dual since Apr 2025) | Indirect (improves modeling) | None — server-side via MMP |
| **Google App Campaigns** | SKAdNetwork + Firebase events | Required for user-level | Firebase + Google Ads SDK |
| **Meta App Install** | AEM + SKAN postbacks | Required for AEM 8-event mapping | Meta SDK or MMP S2S |
| **TikTok App Install** | SKAN + S2S events | Required for user-level | TikTok SDK or MMP |
| **Snap App Install** | SKAN | Required | Snap SDK or MMP |
| **Branch / Adjust / AppsFlyer / Singular (MMP)** | Aggregator across all above + IDFA | Required for user-level | Their SDK |

## Output Pattern

When invoked, the skill should:

1. **Identify the sub-problem** using the decision tree above.
2. **Load the relevant reference file(s)** from `references/`.
3. **Apply the diagnosis or pattern** from that reference.
4. **Reference the exact code call site** (file:line) in the user's project when fixing.
5. **For audits:** produce a scored output (PASS/WARNING/FAIL per check) similar to ads-apple skill's framework.
6. **For new setups:** walk through `references/pre-launch-checklist.md` step by step, gating on each prerequisite.

## What This Skill Will NOT Do

- Web/SPA attribution (use a web-analytics skill instead)
- Apple Search Ads keyword strategy (the ads-apple skill is better for that — delegate)
- ASO / store listing optimization (out of scope)
- Android-only attribution (Android parity notes only; full Android Privacy Sandbox needs its own skill)
- Push notification attribution (different SDK domain)

## Related Skills (Delegate Targets)

If user request is broader than ATT/marketing-attribution:

- **App Store review prep / privacy manifest deep-dive** → delegate to `app-store-review` skill (dpearson2699/swift-ios-skills)
- **Deep link routing / Universal Links / deferred deep link** → delegate to `mobile-deep-linking-specialist` (curiositech/windags-skills)
- **Apple Ads campaign-structure deep audit** → delegate to `ads-apple` (AgriciDaniel/claude-ads) — keep this skill focused on the ATT/MMP/measurement plumbing
- **Cross-channel UA strategy comparison** → delegate to `app-ads` (kostja94/marketing-skills)

## Sources

This skill merges and extends three upstream community skills:

1. **AgriciDaniel/claude-ads → ads-apple** — Apple Ads audit framework, MMP/AAK/ATT integration checklist, ASA Health Score scoring
2. **dpearson2699/swift-ios-skills → adattributionkit** — AdAttributionKit role model, conversion windows, postback tiers, code patterns
3. **mukul975/Privacy-Data-Protection-Skills → managing-mobile-app-consent** — ATT 4-state matrix, pre-permission prompt design, per-SDK consent propagation patterns

Plus anonymized production iOS app incidents which surfaced the `attConsentWaitingInterval` + `trackEvent` gap and the silent capture-protection / Facebook AppEvents denied paths.

See individual `references/*.md` files for detailed playbooks per problem type.
