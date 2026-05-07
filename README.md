# Marketing + ATT Pipeline (iOS) — Claude Code Skill

> Production-grade Claude Code skill for debugging, integrating, and auditing iOS marketing channel attribution under Apple's App Tracking Transparency (ATT) framework.
> Covers AppsFlyer, Adjust, Branch, Singular, Meta App Events, Apple Ads, Google App Campaigns, and TikTok — with SKAdNetwork 4 + AdAttributionKit dual attribution, Conversions API, privacy manifests, and the kind of production gotchas that don't make it into vendor docs.

[![Claude Skill](https://img.shields.io/badge/Claude-Skill-blueviolet)](https://docs.claude.com/en/docs/agents-and-tools/agent-skills/overview)
[![iOS 17.4+](https://img.shields.io/badge/iOS-17.4%2B-blue)](https://developer.apple.com/documentation/apptrackingtransparency)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## What This Skill Solves

If you've ever shipped an iOS app with paid user acquisition, you've seen at least one of these:

- 📉 **"Most of our installs show as Organic in the MMP dashboard"** — even though you're spending six figures on Meta and Apple Ads
- 🪤 **`attConsentWaitingInterval` is set, but events still fire before ATT resolves** — and silently get attributed to Organic forever
- 🤐 **Meta says AEM is configured, but Ads Manager won't let you select it** — and the docs don't explain why
- 💀 **Apple Ads campaigns running, but 80% of installs are Organic** — because the AdServices API token isn't being forwarded
- 🎯 **SKAN postbacks arrive empty after migrating to AdAttributionKit** — turns out one of two API calls got removed
- 🚫 **App Review rejection under Guideline 5.1.2** — the ATT prompt was reachable on yesterday's build but not today's

This skill is a structured, codified playbook for all of the above — pulled from production iOS apps, cross-referenced against Apple, AppsFlyer, Adjust, and Meta documentation, and battle-tested against real incident reports.

When invoked inside Claude Code, the skill activates automatically on keywords like `ATT`, `IDFA`, `SKAdNetwork`, `AppsFlyer`, `Adjust`, `Meta AEM`, `Apple Ads`, `attConsentWaiting`, `organic install surge`, `installs missing`, `events going organic`, and 25+ other triggers.

---

## What Makes This Different

Most marketing-attribution skills focus on either **strategy** (campaign structure, bid optimization) or **single-vendor docs** (just AppsFlyer, just Adjust). This skill focuses specifically on the **plumbing layer** — the place where bugs actually live in production:

- ✅ The **`attConsentWaitingInterval` + `trackEvent` gap** that affects every iOS app using Adjust or AppsFlyer
- ✅ The **capture-protection silent-defer bug** that prevents the ATT prompt from showing for affected users
- ✅ The **Facebook AppEvents silent-drop** when ATT is denied
- ✅ The **`AAAttribution.attributionToken()`** integration that fixes 80%-Organic-on-Apple-Ads
- ✅ The **dual-API-call** requirement during SKAN→AAK migration
- ✅ **React Native + Expo** specifics that vendor docs gloss over
- ✅ A **diagnostic script** that grep's your iOS project for 12 known anti-patterns

It also routes properly: when a question is about strategy or campaign structure rather than plumbing, the skill explicitly delegates to the right upstream skill instead of pretending to be everything.

---

## Quick Start

### Install (per-user, available across all your projects)

```bash
git clone https://github.com/Rylaa/ios-marketing-att-skill \
  ~/.claude/skills/marketing-att-pipeline
```

Restart Claude Code. The skill registers itself and auto-activates on relevant keywords.

### Install (per-project, scoped to one repo)

```bash
cd /path/to/your/ios/project
git clone https://github.com/Rylaa/ios-marketing-att-skill \
  .claude/skills/marketing-att-pipeline
```

### Verify it loaded

In Claude Code, type:

```
What does the marketing-att-pipeline skill cover?
```

Or trigger it organically:

```
We're seeing 60% Organic installs in AppsFlyer after migrating to Adjust v5.
What's wrong?
```

The skill should fire and route to `references/att-timing-and-events.md`.

---

## What's Inside

```
marketing-att-pipeline/
├── SKILL.md                           Skill entry point, decision tree, channel ref
├── WORKFLOW.md                        5-stage operating sequence + 5 ready-made playbooks
├── README.md                          (this file)
├── references/
│   ├── att-timing-and-events.md       MMP wait interval, trackEvent gap, RN/Expo
│   ├── consent-gating.md              ATT 4-state matrix × 6 SDK init pattern
│   ├── adattributionkit-and-skan.md   AAK + SKAN 4 + iOS 18 PostbackUpdate + re-engagement
│   ├── meta-aem-troubleshoot.md       Prerequisites + ATE error + extinfo 16-pos
│   ├── apple-ads-audit.md             ASA Health Score + AdServices API + Maximize Conv
│   ├── pre-launch-checklist.md        10-phase pre-paid-UA checklist
│   ├── tiktok-integration.md          TikTok Business SDK + SKAN ownership matrix
│   └── symptom-to-cause.md            Vague-symptom triage table
└── scripts/
    └── diagnose.sh                    12-check static analysis pass
```

| File | Lines | Purpose |
|---|---|---|
| `SKILL.md` | 192 | Skill registration + decision tree |
| `WORKFLOW.md` | 275 | 5-stage operating sequence |
| `references/adattributionkit-and-skan.md` | 356 | Postback layer reference |
| `references/pre-launch-checklist.md` | 253 | New-app launch playbook |
| `references/meta-aem-troubleshoot.md` | 251 | Meta-specific AEM issues |
| `references/att-timing-and-events.md` | 235 | ATT timing + event gap |
| `references/consent-gating.md` | 208 | ATT 4-state per-SDK init |
| `references/apple-ads-audit.md` | 204 | Apple Ads audit framework |
| `references/symptom-to-cause.md` | 71 | Triage table |
| `scripts/diagnose.sh` | 249 | Static analysis script |
| **Total** | **2,193 lines** | |

---

## Real-World Use Cases

### 1. Debug "installs going Organic"

```
User: We migrated from Adjust v4 to v5 last week. Now 65% of installs in
the AppsFlyer dashboard show as Organic. We didn't change anything else.

Skill response:
1. Routes to references/att-timing-and-events.md
2. Identifies likely cause: Adjust v5 init API rename (appDidLaunch → initSdk)
3. Greps your codebase for `Adjust.appDidLaunch` (still v4 syntax → no-op in v5)
4. Patches with `Adjust.initSdk(adjustConfig)`
5. Verifies `enableFirstSessionDelay()` (method, not property)
6. Suggests verification: fresh install + 48h dashboard check
```

### 2. Pre-launch audit for new iOS app

```
User: We're launching our new subscription app next month. AppsFlyer + Meta
+ Apple Ads. What do we need before flipping on paid UA?

Skill response:
1. Routes to references/pre-launch-checklist.md
2. Walks 10 phases: Info.plist, PrivacyInfo, App Store Connect, MMP SDK init,
   ATT prompt, conversion value mapping, per-channel setup, deep linking,
   verification, day-1 monitoring
3. Generates per-channel SDK init code (Swift + RN/Expo)
4. Produces Conversion Value encoding strategy for subscription apps (multi-window)
5. Runs scripts/diagnose.sh on your project to verify
```

### 3. "Apple Ads installs all show as Organic"

```
User: We have $40K/month on Apple Search Ads. The dashboard shows 12K installs.
AppsFlyer shows 1.8K Apple Ads installs and 11K Organic. Help.

Skill response:
1. Routes to references/apple-ads-audit.md → AdServices API section
2. Diagnoses: AAAttribution.attributionToken() not implemented or not forwarded
3. Provides Swift integration code + AppsFlyer-specific token-forward call
4. Verifies in MMP raw data: `media_source: Apple Search Ads` (not Organic)
5. Suggests waiting 24h to validate
```

### 4. Meta AEM not selectable in Ads Manager

```
User: Meta says our AEM is set up, but in Ads Manager when I create an app
campaign, the AEM event option is greyed out.

Skill response:
1. Routes to references/meta-aem-troubleshoot.md → Prerequisites section
2. Walks 7-step prerequisite checklist (app published, BM association, domain
   verified, 8-event hierarchy, app status, install volume, event sending mech)
3. Identifies likely missing prereq: domain verification or app-to-ad-account
   association
4. Provides specific Meta UI navigation paths
5. Suggests waiting 24-72h after fix → verify in Test Events tab
```

### 5. SKAN→AAK migration broke conversion values

```
User: We migrated to AdAttributionKit on iOS 17.4+. Postbacks arrive but
conversion-value field is always 0 or null.

Skill response:
1. Routes to references/adattributionkit-and-skan.md → Failure Mode 6
2. Greps codebase for both Postback.updateConversionValue and
   SKAdNetwork.updatePostbackConversionValue — both must fire
3. Identifies missing dual-call (common migration regression)
4. Patches the missing path
5. Verifies with simctl log filter on both subsystems
```

### 6. Vague "something feels off"

```
User: Our marketing isn't working anymore. Help.

Skill response:
1. Routes to references/symptom-to-cause.md (triage)
2. Asks Q1-Q4: what specifically broken? when started? which channel? what
   does MMP raw data show?
3. Routes from triage answers to specific reference file
4. Optionally runs scripts/diagnose.sh as cross-check
```

### 7. ATT opt-in rate too low

```
User: Our ATT opt-in rate is at 12%. Industry says 35-50%. Why so low?

Skill response:
1. Routes to references/consent-gating.md → Pre-permission section
2. Reviews your current ATT prompt UX
3. Provides Apple-approved pre-permission screen Swift code (15-25% lift)
4. Reviews NSUserTrackingUsageDescription wording
5. Lists App Review rejection patterns to avoid (incentive ban, two-button
   effective-deny, vague third-party language, modal stacking)
```

### 8. RN/Expo + Adjust integration

```
User: First time integrating Adjust in a React Native + Expo app. What's
the order of operations?

Skill response:
1. Routes to references/att-timing-and-events.md → React Native + Expo section
2. Provides JS bridge code: AdjustConfig + setAttConsentWaitingInterval +
   enableFirstSessionDelay
3. Adds expo-tracking-transparency for the ATT prompt
4. Calls out Expo Go limitation (must use dev client / standalone)
5. Notes plugin-version-must-match-native-SDK-version constraint
```

---

## The Diagnostic Script

```bash
bash ~/.claude/skills/marketing-att-pipeline/scripts/diagnose.sh /path/to/ios/project
```

Performs **12 static checks** on your iOS project source:

| # | Check | What it catches |
|---|---|---|
| 1 | `NSUserTrackingUsageDescription` | ATT prompt would crash without it |
| 2 | `SKAdNetworkItems` | No SKAN postbacks possible |
| 3 | `PrivacyInfo.xcprivacy` | App Review rejection (iOS 17+) |
| 4 | `AdAttributionKit` plist key | AAK postback copy not enabled |
| 5 | AppsFlyer `waitForATTUserAuthorization` | Install ships before ATT resolves |
| 6 | Adjust `attConsentWaitingInterval` | Same problem on Adjust |
| 7 | `ATTrackingManager` request call site | ATT never actually requested |
| 8 | `trackEvent` + ATT-gating heuristic | The Production-class trackEvent gap |
| 8b | Capture-protection silent-defer | `isCaptured` near `requestTrackingAuthorization` |
| 8c | SDK init order | Wait config before `start()` / `initSdk()` |
| 9 | SKAN/AAK conversion value updates | Postbacks won't carry CV data |
| 10 | Marketing SDK inventory | Auto-detect AppsFlyer/Adjust/Branch/Singular/Meta/Firebase/AdMob |

Output:

```
=== iOS Marketing + ATT Pipeline Diagnosis ===
Root: /Users/me/Projects/MyApp

[1/10] NSUserTrackingUsageDescription
✓ found in Info.plist

[2/10] SKAdNetworkItems
✓ SKAdNetworkItems present

[3/10] PrivacyInfo.xcprivacy
✓ PrivacyInfo.xcprivacy exists

[4/10] AdAttributionKit
⚠ no AttributionCopyEndpoint — server-side postback mirror not enabled

[5/10] AppsFlyer ATT wait config
✓ AppsFlyer wait config found

[6/10] Adjust ATT wait config
⚠ no attConsentWaitingInterval — skip if not using Adjust

[7/10] ATT prompt invocation
✓ ATT request found

[8/10] trackEvent / logEvent call sites + ATT-gating
✗ 14 trackEvent/logEvent call sites; ~3 file(s) lack any ATT-gating reference

[8b] Capture-protection ATT defer
   (no findings)

[8c] SDK init order (waitFor* config BEFORE start)
   (passing)

[9/10] SKAN/AAK conversion value updates
✓ conversion value update calls found

[10/10] Marketing SDK inventory
✓ marketing SDKs detected:
  → AppsFlyer
  → Meta SDK
  → Firebase
```

PASS / WARN / FAIL color-coded, with action items per finding.

---

## Trigger Keywords (for skill auto-invocation)

The skill activates automatically when Claude Code detects any of these in user input:

**Core ATT:** ATT, IDFA, ATTrackingManager, NSUserTrackingUsageDescription, App Tracking Transparency, attConsentWaiting, "tracking authorization"

**MMP SDKs:** AppsFlyer, AppsFlyerLib, Adjust, Branch, Singular, MMP, "mobile measurement partner"

**Postback layer:** SKAdNetwork, SKAN, AdAttributionKit, AAK, conversion value, postback, conversion window, dual attribution

**Channels:** Apple Ads, Apple Search Ads, ASA, Google App Campaigns, GAC, UAC, Meta App Install, Meta AEM, ATE, Aggregated Event Measurement, TikTok App Install

**Symptoms:** organic install surge, "installs missing", "events going organic", "attribution broken", "spend not converting"

**Privacy:** privacy manifest, PrivacyInfo.xcprivacy, required reason API, App Privacy

**Setup keywords:** install attribution, conversion value mapping, install order, SDK init order, Firebase iOS attribution

---

## Workflow Operating Sequence

For any task, the skill follows a 5-stage flow defined in `WORKFLOW.md`:

```
┌──────────────┐   ┌──────────┐   ┌──────────────┐   ┌──────┐   ┌─────────┐
│ 1. CONTEXT   │ → │ 2. ROUTE │ → │ 3. DIAGNOSE  │ → │ 4. ACT│ → │ 5. VERIFY│
└──────────────┘   └──────────┘   └──────────────┘   └──────┘   └─────────┘
```

**1. CONTEXT** — Gather: iOS-only or RN/Expo, MMP choice, channels active, iOS min target, app type (sub/IAP/utility), build environment (App Store/TestFlight/local), symptom or goal.

**2. ROUTE** — Map user's stated problem to ONE primary reference file via decision tree.

**3. DIAGNOSE** — Read the reference fully, grep for relevant symbols in user's project, run `diagnose.sh` if appropriate.

**4. ACT** — Three modes: direct fix (Mode A), recommendation only (Mode B), or audit with score (Mode C).

**5. VERIFY** — Compile-time + static (re-run diagnose) + runtime (real device fresh install + 24-48h dashboard check).

`WORKFLOW.md` includes 5 ready-made multi-stage playbooks: post-ship attribution drop, pre-launch new app, ASA + AppsFlyer audit, Meta AEM not selectable, SKAN→AAK migration regression.

---

## Compatibility Matrix

| iOS minimum target | Skill features available |
|---|---|
| iOS 14.5+ | Core ATT + SKAN 3 |
| iOS 16.1+ | + SKAN 4 (3 windows, fine + coarse, lockWindow) |
| iOS 17.4+ | + AdAttributionKit (single-value API) |
| iOS 18.0+ | + AAK PostbackUpdate type, conversion types |
| iOS 18.4+ | + AAK in-Settings developer mode (5-10 min postbacks) |

| MMP / SDK | Recommended version |
|---|---|
| Adjust iOS SDK | v5.x current line; v4.34.0 minimum |
| AppsFlyer iOS SDK | 6.14+ (full SKAN 4 + AAK support) |
| Meta SDK (iOS) | 17+ (privacy manifest); 18+ for iOS 17 ATT auto-detection |
| Google Mobile Ads | 11.x+ |
| Firebase iOS SDK | 10.21+ |
| TikTok Business iOS SDK | 1.4+ for privacy manifest |

---

## What This Skill Does NOT Do

To keep the scope manageable, the following are out of scope:

- ❌ **Web / SPA attribution** — use a web analytics skill
- ❌ **Apple Search Ads keyword strategy / bid tuning** — delegate to upstream `ads-apple` skill
- ❌ **ASO / store listing optimization** — separate domain
- ❌ **Android Privacy Sandbox** — Android-specific, separate skill needed
- ❌ **Push notification attribution** — different SDK domain
- ❌ **OAuth / authentication flows** — `auth-specialist` skill
- ❌ **GA4 / web analytics deep dive** — use a web analytics skill

When the skill detects a question outside its scope, it explicitly delegates rather than guessing.

---

## Origin & Credits

This skill merges three excellent upstream community skills:

| Upstream | Used For |
|---|---|
| [`AgriciDaniel/claude-ads → ads-apple`](https://github.com/AgriciDaniel/claude-ads) | Apple Ads audit framework, MMP/AAK/ATT integration checklist, ASA Health Score scoring |
| [`dpearson2699/swift-ios-skills → adattributionkit`](https://github.com/dpearson2699/swift-ios-skills) | AdAttributionKit role model, conversion windows, postback tiers, code patterns |
| [`mukul975/Privacy-Data-Protection-Skills → managing-mobile-app-consent`](https://github.com/mukul975/Privacy-Data-Protection-Skills) | ATT 4-state matrix, pre-permission prompt design, per-SDK consent propagation patterns |

**Plus production lessons** from real iOS app incidents that surfaced:

- The `attConsentWaitingInterval` + `trackEvent` gap (different code paths, both leak)
- The capture-protection silent-defer bug (ATT prompt never shows for affected users)
- The Facebook AppEvents silent-drop on ATT-denied users
- The dual-API-call requirement for SKAN ↔ AAK interop

These production incidents are what differentiate this skill from a "merge of three skills" — they're patterns that show up in real apps and aren't documented in vendor docs.

---

## Diagnostic Output Examples

### Healthy project

```
[1/10] NSUserTrackingUsageDescription          ✓
[2/10] SKAdNetworkItems                        ✓
[3/10] PrivacyInfo.xcprivacy                   ✓
[4/10] AdAttributionKit                        ✓
[5/10] AppsFlyer ATT wait config               ✓
[6/10] Adjust ATT wait config                  (skipped — Adjust not used)
[7/10] ATT prompt invocation                   ✓
[8/10] trackEvent / logEvent call sites        ⚠ 14 sites — manual review
[8b]  Capture-protection ATT defer            (no findings)
[8c]  SDK init order                          ✓
[9/10] SKAN/AAK conversion value updates       ✓
[10/10] Marketing SDK inventory                ✓ AppsFlyer, Meta, Firebase
```

### Production-class incident project (fictional reproduction)

```
[8/10] trackEvent / logEvent call sites + ATT-gating
✗ 17 trackEvent/logEvent call sites; ~5 file(s) lack any ATT-gating reference
   /Features/Splash/SplashView.swift:39
   /Features/Onboarding/HeroPage.swift:250
   /Features/Onboarding/EffectPickerPage.swift:388
   /AppCore/ApplicationDelegate.swift:486
   /Features/Onboarding/LoadingPage.swift:179

[8b] Capture-protection ATT defer
✗ /AppCore/ATTController.swift uses isCaptured near requestTrackingAuthorization
   → Add a hard timeout fallback so prompt fires regardless of capture state
```

---

## Roadmap / Known Limitations

This skill is at v1.2.0. Recent work:

### Resolved in v1.2.0

- ✅ **Meta AEM 8-event hierarchy** — replaced with auto-aggregate guidance (Meta retired manual prioritization in June 2025)
- ✅ **`Settings.shared.isAdvertiserTrackingEnabled` iOS 17+ deprecation** — wrapped in `if #unavailable(iOS 17) { ... }` blocks
- ✅ **`NSAdvertisingAttributionReportEndpoint` plist key** — added to pre-launch checklist + AAK reference with provider URL table (Adjust, AppsFlyer, Branch, Singular)
- ✅ **TikTok integration** — new dedicated `references/tiktok-integration.md` with full init, SKAN ownership decision matrix, hybrid MMP+SDK setup

### Possible v1.3 additions

- Branch.io specific gotchas (`branch_referrable` flag, deferred deep link sandbox)
- Singular SKAN Decoder pattern
- Conversions API server-side flow for Meta/TikTok
- Firebase + GA4 attribution consolidated reference
- iOS 26 ATT persistence change documentation (when Apple confirms)

PRs welcome — see "Contributing" below.

---

## Contributing

Contributions are welcome. Especially valued:

- **Production incident write-ups** — real bugs from real apps with real symptoms and the actual fix
- **Vendor doc updates** — when AppsFlyer, Adjust, Meta, Apple change their APIs (this happens often)
- **iOS version updates** — when Apple releases new ATT/AAK behavior
- **`diagnose.sh` improvements** — additional checks, better heuristics, false-positive reduction

### Pull Request Workflow

1. Fork + branch
2. Make changes; if you're adding a reference file, link it from `SKILL.md` decision tree AND `WORKFLOW.md` routing matrix
3. Run `bash scripts/diagnose.sh /tmp` (sanity check the script still parses)
4. Update `CHANGELOG.md` with what changed
5. Bump `metadata.version` in `SKILL.md` frontmatter
6. Submit PR with: what changed, why, link to incident report if applicable

### Style Conventions

- **Markdown:** GitHub-flavored, no HTML except in tables
- **Code samples:** Swift 5.9+ for native iOS, TypeScript for RN/Expo
- **No emoji in skill body files** (only in this README)
- **Keep references short and dense** — readers will scan, not read

---

## Citation / Attribution

If you write about, fork, or reference this skill, the following citation is appreciated but not required:

```
Marketing + ATT Pipeline (iOS) Claude Code Skill
https://github.com/Rylaa/ios-marketing-att-skill
```

The skill itself credits its three upstream sources in `SKILL.md`'s `metadata.sources` field.

---

## License

MIT License — see [LICENSE](LICENSE) file.

This means you can:
- Use it commercially
- Modify it
- Distribute it
- Use it privately

You must:
- Include the copyright notice and license in copies/substantial portions

The three upstream sources are also MIT or Apache-2.0 licensed, so this aggregated work has no licensing conflicts.

---

## Maintenance

| Field | Value |
|---|---|
| **Skill version** | 1.2.0 |
| **Last verified** | 2026-05-07 |
| **iOS baseline** | 17.4+ for AAK; 18+ for `PostbackUpdate` API |
| **Status** | Active — used in production by maintainer |

When iOS major versions change (annual September) or any of the credited MMP SDKs ship a major version, expect updates within 2-4 weeks. File an issue if something looks stale.

---

## Related Skills (Not Included Here)

If your question is broader than iOS marketing attribution, these adjacent skills are worth installing:

- **`ads-apple`** ([AgriciDaniel/claude-ads](https://github.com/AgriciDaniel/claude-ads)) — Apple Ads campaign strategy, bid optimization, CPP testing, keyword research
- **`adattributionkit`** ([dpearson2699/swift-ios-skills](https://github.com/dpearson2699/swift-ios-skills)) — Even deeper AAK-only reference; this skill borrows from it
- **`app-store-review`** ([dpearson2699/swift-ios-skills](https://github.com/dpearson2699/swift-ios-skills)) — App Store rejection prevention, privacy manifest deep dive, IAP review rules
- **`mobile-deep-linking-specialist`** ([curiositech/windags-skills](https://github.com/curiositech/windags-skills)) — Universal Links, App Links, deferred deep linking, attribution
- **`managing-mobile-app-consent`** ([mukul975/Privacy-Data-Protection-Skills](https://github.com/mukul975/Privacy-Data-Protection-Skills)) — GDPR / EU consent flows, Android Privacy Sandbox, regulatory compliance

The `marketing-att-pipeline` skill explicitly delegates to these when the user's question falls outside its scope.

---

## FAQ

**Q: Does this skill work with non-Claude AI assistants?**
A: It's structured as a Claude Code skill with auto-discovery via the `Skill` tool. Other assistants that support skill-style markdown registration (Cursor's rules, GitHub Copilot's instructions) can use the content but won't get auto-routing — you'd need to manually load the relevant reference file.

**Q: Why merge upstream skills instead of just installing them all?**
A: Skill auto-discovery picks the first-matching skill on a keyword. Three overlapping skills means unpredictable routing and missed coverage. A merged skill with explicit decision tree gives consistent behavior. Plus the merge adds production incident knowledge that none of the upstreams have.

**Q: Can I use this in a non-iOS context?**
A: No — the entire skill assumes iOS. Cross-platform (RN/Expo) is partially covered for the JS bridge layer, but the Apple ATT/AAK/SKAN frameworks are iOS-only. Android marketing attribution is a different beast.

**Q: How is this different from just reading the AppsFlyer / Adjust / Apple docs?**
A: Vendor docs tell you the API surface. This skill tells you what goes wrong in production, where the docs are misleading, and which specific code paths trigger which specific symptoms. It's the difference between a reference manual and a debugging playbook.

**Q: Will this skill be maintained?**
A: Yes — the maintainer uses it in production iOS apps, so it gets updated whenever a new iOS release or MMP SDK version breaks something. Expect 2-4 update cycles per year.

**Q: Can I integrate this into a CI pipeline?**
A: Yes — `scripts/diagnose.sh` is designed to be runnable headless. Add it to your iOS CI as a non-blocking warning step:
```yaml
- name: Marketing-ATT Diagnostics
  run: bash .claude/skills/marketing-att-pipeline/scripts/diagnose.sh .
  continue-on-error: true
```

---

## Acknowledgments

- **Apple's ATT, SKAdNetwork, and AdAttributionKit teams** for documentation that, while sometimes confusing, is at least available
- **AppsFlyer, Adjust, and Meta engineering teams** whose support tickets, changelog notes, and developer forum answers built the institutional knowledge this skill captures
- **The community skill authors** (AgriciDaniel, dpearson2699, mukul975) whose work is the foundation
- **Anthropic** for Claude Code and the skill system that makes this kind of structured, discoverable expertise possible

---

**Built for iOS engineers who'd rather fix the bug than read the docs.**
