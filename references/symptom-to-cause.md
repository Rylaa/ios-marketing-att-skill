# Symptom → Cause → Fix (Triage Table)

When user describes a problem with vague symptoms, walk this table top-to-bottom until match.

| Symptom | Likely Cause | Read Next |
|---|---|---|
| "Installs going Organic in MMP" | ATT timing — install payload sent before ATT response, IDFA all zeros | `att-timing-and-events.md` |
| "Most installs Organic, paid spend looks wasted" | Same as above + missing AdAttributionKit fallback | `att-timing-and-events.md` + `adattributionkit-and-skan.md` |
| "Events going Organic but install OK" | Event pipe is outside the SDK wait queue, or emitted before wait/consent config | `att-timing-and-events.md` (Defense 2) |
| "Install attributed but in-app events missing" | Events firing before SDK init OR consent flag not set | `consent-gating.md` |
| "Meta AEM doesn't appear in Ads Manager" | Prerequisite not met: domain/event/ad-account assoc | `meta-aem-troubleshoot.md` (Prerequisites) |
| "Meta ATE verification error" | Payload param missing OR hashing mismatch OR app ID mismatch | `meta-aem-troubleshoot.md` (ATE section) |
| "AppsFlyer + Meta + RN/Expo not working" | Plugin version OR `timeToWaitForATTUserAuthorization` not set in JS | `meta-aem-troubleshoot.md` (RN/Expo section) |
| "SKAN postback never arrives" | `updateConversionValue(0)` never called → window never opened | `adattributionkit-and-skan.md` (Failure Mode 2) |
| "All postbacks Tier 0, no useful data" | Campaign volume too low for crowd anonymity | `adattributionkit-and-skan.md` (Failure Mode 1) |
| "Apple Ads dashboard shows installs but MMP doesn't" | Apple Ads partner not enabled in MMP OR dual-attribution dedup misconfigured | `apple-ads-audit.md` |
| "ATT opt-in rate <15%" | Bad prompt UX (no pre-permission, fires on cold start) | `consent-gating.md` (Pre-permission section) |
| "ATT prompt never shows for some users" | Capture-protection silent-defer OR modal stacking OR keychain residue | `att-timing-and-events.md` (Capture-Protection bug) |
| "Worked yesterday, broken today, no code change" | MMP partner config changed OR Apple changed conversion window OR SDK auto-update | Check MMP changelog + Apple SKAN release notes |
| "iOS users show much lower CTR than Android" | Different — likely creative or audience, not attribution | Out of scope; use `app-ads` skill |
| "Push notification deep links not attributing" | Different domain | Use `mobile-deep-linking-specialist` skill |
| "Web → app install attribution missing" | Domain not verified in Meta + branch link config | `meta-aem-troubleshoot.md` Prerequisite #4 + delegate to deep-linking |
| "TestFlight installs not showing in MMP" | TestFlight/local installs do not exercise real paid attribution and AEM doesn't activate pre-release | Expected; verify with production App Store attribution paths / MMP test tools |
| "Privacy review rejection in App Review" | `PrivacyInfo.xcprivacy` mismatch with actual SDK behavior | `pre-launch-checklist.md` Phase 2 + delegate to `app-store-review` |
| "Apple's `idfa=00000000-...` for ATT-authorized user" | Reset IDFA in Settings → app reads cached value | Do NOT cache IDFA; read fresh at event-send via `ASIdentifierManager.shared().advertisingIdentifier` |
| "80% Apple Ads installs show as Organic" | AdServices API token not fetched/forwarded to MMP | `apple-ads-audit.md` (AdServices API section) |

## Decision Flow for Vague Reports

```
User: "Our marketing isn't working"
│
├─ Q1: What does "not working" mean specifically?
│   ├─ "spend not converting" → not attribution issue, check creative/audience
│   ├─ "installs not attributed" → att-timing-and-events.md
│   ├─ "events missing" → consent-gating.md OR meta-aem-troubleshoot.md
│   └─ "dashboards don't match" → apple-ads-audit.md (cross-check section)
│
├─ Q2: When did it start? (regression vs always-broken)
│   ├─ "Always" → likely setup issue, run pre-launch-checklist
│   ├─ "After we updated SDK" → SDK changelog
│   ├─ "After iOS update" → Apple release notes
│   └─ "After we added X channel" → that channel's setup
│
├─ Q3: Which platform/channel?
│   ├─ Meta → meta-aem-troubleshoot.md
│   ├─ Apple Ads → apple-ads-audit.md
│   ├─ Google → check Firebase + GAC docs (out of scope here)
│   └─ All → likely cross-cutting MMP/ATT issue → att-timing-and-events.md
│
└─ Q4: What does the MMP raw data show?
    ├─ "idfa=null + att=denied" → expected for denied users; check SKAN postbacks
    ├─ "idfa=null + att=authorized" → Settings reset IDFA; re-fetch
    ├─ "idfa=null + att=notDetermined" → ATT timing bug
    └─ "idfa=real + still organic" → Apple Ads partner config OR conversion value mapping
```

## When To Escalate Out of This Skill

| Situation | Delegate To |
|---|---|
| Apple Ads keyword strategy / bid optimization | `ads-apple` (AgriciDaniel/claude-ads) |
| Cross-channel UA strategy comparison | `app-ads` (kostja94/marketing-skills) |
| Deep link routing problems | `mobile-deep-linking-specialist` (curiositech/windags-skills) |
| App Store rejection / privacy manifest deep dive | `app-store-review` (dpearson2699/swift-ios-skills) |
| AAK code-level integration | `adattributionkit` (dpearson2699/swift-ios-skills) ← upstream of this skill |
| Web analytics / GA4 attribution | Out of scope — find a web analytics skill |

## Related

All other reference files in this skill — this is the entry triage doc.
