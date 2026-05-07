# Workflow / Operating Sequence

Standard 5-stage flow this skill follows for any task. Use this BEFORE the decision tree in `SKILL.md`.

```
┌──────────────┐   ┌──────────┐   ┌──────────────┐   ┌──────┐   ┌─────────┐
│ 1. CONTEXT   │ → │ 2. ROUTE │ → │ 3. DIAGNOSE  │ → │ 4. ACT│ → │ 5. VERIFY│
└──────────────┘   └──────────┘   └──────────────┘   └──────┘   └─────────┘
   gather what       pick reference   read & apply       fix or       confirm
   we're solving     file(s)          patterns           recommend    fix worked
```

---

## Stage 1: CONTEXT — Gather Before Acting

**Goal:** know what you're dealing with before opening any reference file.

**Mandatory inputs to collect from the user (or infer from project state):**

| Question | Why it matters |
|---|---|
| iOS-only / Android too / cross-platform? | Skill is iOS-focused; cross-platform changes scope |
| Native Swift / RN / Flutter / Expo / KMP? | RN/Expo has different SDK init paths |
| Which MMP? (AppsFlyer / Adjust / Branch / Singular / none) | Each has different APIs + dashboards |
| Which channels active? (Apple Ads / Meta / Google / TikTok / Snap / others) | Routes to channel-specific reference |
| iOS minimum deployment target? | Determines AAK availability (iOS 17.4+), iOS 18 PostbackUpdate API |
| Subscription / IAP / e-commerce / utility? | Determines CV encoding strategy |
| Live in App Store, TestFlight, or local dev? | TestFlight/local builds do not exercise real paid install, AdServices, SKAN/AAK, or AEM production paths |
| Symptom or goal? (debug vs new setup vs audit) | Routes to right decision tree branch |

**Project-state checks (run in parallel if you have project access):**

```bash
# Detect MMP SDKs
ls Pods/ 2>/dev/null | grep -E "AppsFlyer|Adjust|Branch|Singular"
grep -rln "import AppsFlyerLib\|import AdjustSdk\|import Branch" --include="*.swift" --include="*.ts" .

# Detect ATT integration
grep -rln "ATTrackingManager\|requestTrackingPermissionsAsync" --include="*.swift" --include="*.ts" .

# Check Info.plist
find . -name "Info.plist" -not -path "*/Pods/*" | head -3

# If existing project: run the diagnostic script
bash ~/.claude/skills/marketing-att-pipeline/scripts/diagnose.sh .
```

**STOP signal:** if context is ambiguous (e.g., user says "fix our attribution" without saying which MMP or what symptom), ASK before proceeding. Do not guess. Misrouting wastes context.

---

## Stage 2: ROUTE — Pick the Right Reference File

Use the SKILL.md decision tree to map the user's stated problem to ONE primary reference file. Only fan out to multiple references when the diagnosis explicitly demands it.

### Standard routing matrix

| User says... | Primary route | Secondary if needed |
|---|---|---|
| "Installs going Organic / paid spend wasted" | `att-timing-and-events.md` | `adattributionkit-and-skan.md` (fallback layer) |
| "Events disappeared / dashboard shows half" | `consent-gating.md` | `att-timing-and-events.md` (Defense 2) |
| "Meta AEM / ATE / Facebook events" | `meta-aem-troubleshoot.md` | `consent-gating.md` (FB AppEvents silent-drop) |
| "TikTok SDK init / SKAN ownership" | `tiktok-integration.md` | `consent-gating.md` (post-ATT enable) |
| "Apple Ads showing Organic" | `apple-ads-audit.md` (AdServices section) | `adattributionkit-and-skan.md` |
| "SKAN postback empty / weird CVs" | `adattributionkit-and-skan.md` | — |
| "Should we prompt ATT now or later" | `consent-gating.md` (Pre-permission) | `att-timing-and-events.md` (When to prompt) |
| "New iOS app launching paid UA" | `pre-launch-checklist.md` | All others as referenced |
| "Audit our setup" | `apple-ads-audit.md` + `pre-launch-checklist.md` (verify) | `symptom-to-cause.md` |
| Vague / "something feels off" | `symptom-to-cause.md` (triage table) | Then route per table result |

### Anti-patterns

- **Don't open all 7 references on every question.** That's context bloat. Open one, read it fully, only escalate if it points elsewhere.
- **Don't use the decision tree to pre-filter the user's wording.** If the user says "AEM not visible" but actually has an AdServices issue, the symptom-to-cause table catches that. Trust the symptom they describe.

---

## Stage 3: DIAGNOSE — Read & Apply Patterns

Once routed:

1. **Read the chosen reference file FULLY.** Don't skim. Each one is short (5-10K) and dense.
2. **Match the user's specific situation against named patterns** in that file (e.g., "Failure Mode 2", "Capture-Protection bug", "ATE verification error").
3. **For code-level diagnosis:** if you have project access, grep for the exact symbol the reference highlights:
   - `attConsentWaitingInterval`, `enableFirstSessionDelay`, `waitForATTUserAuthorization`, `setAttConsentWaitingInterval`
   - `Adjust.initSdk`, `Adjust.appDidLaunch`, `AppsFlyerLib.shared().start`
   - `requestTrackingAuthorization`, `requestTrackingPermissionsAsync`
   - `AppEvents.shared.logEvent`, `Adjust.trackEvent`, `appsFlyer.logEvent`
   - `isCaptured`, `Postback.updateConversionValue`, `SKAdNetwork.updatePostbackConversionValue`
   - `AAAttribution.attributionToken`, MMP AdServices / Apple Ads integration settings
4. **Cite file:line in the user's project** when explaining root cause. Concrete > abstract.
5. **If the reference points to another reference** (Related section), follow only if the current file doesn't fully answer the question.

### When to run `diagnose.sh`

Run on the user's project FOR ANY of these triggers:
- Vague "attribution feels off" reports
- Pre-launch verification request
- Post-incident root-cause hunt
- After applying a fix, to confirm no other related issues remain

```bash
bash ~/.claude/skills/marketing-att-pipeline/scripts/diagnose.sh /path/to/ios/project
```

Read the output: each PASS/WARN/FAIL maps to a reference file (script tells you which one).

---

## Stage 4: ACT — Fix or Recommend

Three modes depending on user request:

### Mode A: Direct fix (user gave permission to edit code)

1. Show the exact diff (file:line + before/after)
2. Apply via Edit tool
3. Run `diagnose.sh` again to confirm the specific check now passes
4. Move to Stage 5

### Mode B: Recommendation (user wants advice, not edits)

1. Produce a concrete patch description: "in `Config/Adjust/AdjustConfiguration.swift:689`, choose `config?.attConsentWaitingInterval = 120` OR `config?.enableFirstSessionDelay()`; do not combine both because first-session delay ignores the ATT wait interval"
2. Show what behavior the patch fixes (e.g., "first session is held until ATT/consent resolves, and unmanaged event pipes are gated separately")
3. Provide verification steps for them to run after applying

### Mode C: Audit (user wants score, not fixes)

1. Apply scoring framework from `apple-ads-audit.md` (or relevant file)
2. Output structured PASS/WARN/FAIL with severity
3. Prioritize fixes (P0/P1/P2) with effort estimates
4. Stop — don't auto-edit

### Output format (all modes)

Every fix/recommendation MUST include:
- **Where:** file:line in the user's project
- **What:** the change in concrete terms
- **Why:** which production failure pattern this prevents (cite the reference file)
- **Verify:** how to confirm the fix worked

---

## Stage 5: VERIFY — Confirm the Fix Worked

Skip only for pure-advisory mode. For any code-level fix:

### Compile-time verification

- Build succeeds (`xcodebuild` or `pod install && xcodebuild`)
- No new warnings in marketing SDK init paths
- For RN/Expo: `npx expo prebuild` succeeds + plugin loaded

### Static verification

- Re-run `bash scripts/diagnose.sh /project` — check that previously-failing checks now PASS
- Manual grep for the anti-pattern you fixed

### Runtime verification (most important)

The user must test on a real device. Walk them through:

1. **Fresh install** on a test device (delete app + clear keychain residue if relevant)
2. **Trigger the ATT prompt path** — accept on one test, deny on another
3. **Check MMP dashboard within 30 mins:** install appears with correct `att_status` and `idfa` (real or null per ATT decision)
4. **Wait 24-48h:** SKAN/AAK postback arrives at MMP
5. **For Meta/AEM:** event appears in Meta Events Manager → Test Events tab within 30s
6. **For Apple Ads:** install attributes to a real campaign (NOT "Organic") within MMP

If any verification step fails, return to Stage 3 (DIAGNOSE) with the new symptom.

---

## Common Multi-Stage Sequences

### Sequence A: "Production attribution-loss incident" (post-ship attribution drop)

```
1. CONTEXT      → ask: when started, % drop, channels affected, recent SDK updates
2. ROUTE        → symptom-to-cause.md → likely att-timing-and-events.md
3. DIAGNOSE     → run diagnose.sh, grep trackEvent + AttResolver,
                  read incident reports if cited
4. ACT          → identify call sites where trackEvent fires before ATT resolves
                  patch with AttResolver wrapper
5. VERIFY       → fresh install test + 48h dashboard recheck
```

### Sequence B: "Pre-launch new iOS app"

```
1. CONTEXT      → ask: which channels planned, MMP choice, iOS min target,
                  current Info.plist state
2. ROUTE        → pre-launch-checklist.md (master), then drill into:
                  consent-gating (ATT prompt design)
                  adattributionkit-and-skan (CV mapping)
                  meta-aem-troubleshoot (if Meta in mix)
3. DIAGNOSE     → walk all 10 phases of pre-launch checklist
4. ACT          → produce ordered Info.plist + SDK init code + CV mapping
5. VERIFY       → diagnose.sh PASS on all checks + Day-7 readiness review
```

### Sequence C: "Audit existing ASA + AppsFlyer setup"

```
1. CONTEXT      → request data: campaign list, MMP dashboard exports,
                  ATT opt-in %, postback success %
2. ROUTE        → apple-ads-audit.md (15% MMP/ATT slice)
3. DIAGNOSE     → run scoring framework, identify FAIL/WARN per check
4. ACT          → produce scored audit output + prioritized fix list
                  delegate strategy questions to upstream ads-apple skill
5. VERIFY       → user implements top-3 fixes, re-audit in 2 weeks
```

### Sequence D: "Meta AEM not selectable in Ads Manager"

```
1. CONTEXT      → ask: app published? Business Manager assoc? domain verified?
                  AEM/event sharing and MMP event mapping enabled?
2. ROUTE        → meta-aem-troubleshoot.md (Prerequisites section)
3. DIAGNOSE     → walk 7-step prerequisite checklist
4. ACT          → identify which prereq is missing → user fixes via Meta UI
                  may also need AppsFlyer dashboard config change
5. VERIFY       → wait 24-72h → AEM toggle visible in Ads Manager → green
                  checkmark in Events Manager → Test Events tab
```

### Sequence E: "SKAN→AAK migration broke conversion values"

```
1. CONTEXT      → confirm migration done, ask: dual-call or one-or-other?
                  iOS min target ≥ 17.4?
2. ROUTE        → adattributionkit-and-skan.md (Failure Mode 6)
3. DIAGNOSE     → grep for both Postback.updateConversionValue AND
                  SKAdNetwork.updatePostbackConversionValue — both should fire
                  Run simctl log filter for both subsystems
4. ACT          → restore the missing API call OR fix MMP endpoint config
5. VERIFY       → simctl log shows both subsystems emit postbacks
                  MMP receives traffic on both legacy and new endpoints
```

---

## Cross-Skill Delegation Triggers

If during any stage you realize the user's actual problem is OUT OF SCOPE for this skill, hand off cleanly:

| Symptom | Hand off to |
|---|---|
| Apple Ads keyword research / bid strategy | `ads-apple` (AgriciDaniel/claude-ads) |
| Cross-channel UA strategy comparison | `app-ads` (kostja94/marketing-skills) |
| Universal Links / deferred deep link routing | `mobile-deep-linking-specialist` |
| App Store rejection / privacy manifest review | `app-store-review` (dpearson2699) |
| AAK low-level code patterns deep dive | `adattributionkit` (dpearson2699 — upstream) |
| Web / GA4 attribution | (find a web analytics skill) |
| Android Privacy Sandbox | (out of scope — Android skill needed) |

When delegating: state explicitly "this is outside marketing-att-pipeline scope; you should invoke X skill" — don't just stop helping.

---

## Maintenance / Versioning

This workflow assumes:

- iOS 17.4+ (AdAttributionKit baseline) — most checks; iOS 18+ for `PostbackUpdate` API
- Adjust v5.x current; v4.34+ minimum
- AppsFlyer 6.14+ for full SKAN 4 + AAK
- Apple Ads AdServices and privacy-preserving postback paths considered separately; do not assume raw double logs for every install
- Maximize Conversions GA (Feb 2026+) acknowledged but not yet ROAS-optimizing

When versions drift:
- Refresh `pre-launch-checklist.md` Phase 4 SDK code samples
- Update `att-timing-and-events.md` API examples
- Re-verify `apple-ads-audit.md` AdServices and MMP-specific guidance
- Bump `metadata.updated` in SKILL.md
