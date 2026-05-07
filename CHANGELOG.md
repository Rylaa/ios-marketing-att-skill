# Changelog

All notable changes to the `marketing-att-pipeline` skill are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.2.0] — 2026-05-07

CRITICAL fixes addressing the four outstanding gaps from v1.1.0's Roadmap.
Applied via four parallel sub-agent edits.

### Added
- **`references/tiktok-integration.md`** — new 250-line reference covering
  TikTokBusinessSDK init, `disableSKAdNetworkSupport()`,
  `suppressAppTrackingDialog()`, SKAN ownership decision matrix, hybrid
  MMP+SDK setup, Events API server-side flow, common failure modes
- **`NSAdvertisingAttributionReportEndpoint`** documentation in
  `pre-launch-checklist.md` (Phase 1 plist + checklist) and
  `adattributionkit-and-skan.md` (new "Postback Copy Endpoints — SKAN vs AAK
  (Two Different Keys)" section). Critical SKAN postback-copy key with provider
  URL table (Adjust, AppsFlyer, Branch, Singular).
- **iOS 17+ Meta SDK behavior change callout** in `consent-gating.md` —
  explains `Settings.shared.isAdvertiserTrackingEnabled` is deprecated; SDK
  reads `ATTrackingManager` directly
- **Historical context callout** in `meta-aem-troubleshoot.md` for the
  retired 8-event hierarchy (in case readers see old docs/Stack Overflow)
- TikTok-specific routing entry in SKILL.md decision tree
- TikTok-specific entry in WORKFLOW.md routing matrix

### Changed
- **Meta AEM 8-event hierarchy section REMOVED** from
  `meta-aem-troubleshoot.md` — Meta retired manual prioritization in
  June 2025. Replaced with "AEM auto-aggregates all eligible events; verify
  via Events Manager → Test Events tab" guidance.
- **`Settings.shared.isAdvertiserTrackingEnabled` calls wrapped** in
  `if #unavailable(iOS 17) { ... }` blocks in `consent-gating.md`. ATT State
  Matrix table annotated with `(iOS <17 only)` for affected cells.
- "Facebook AppEvents Silent-Denied Bug" GOOD example updated to use
  `ATTrackingManager.trackingAuthorizationStatus == .authorized` (cross-iOS
  correct) instead of the deprecated setter check
- `adattributionkit-and-skan.md` "AttributionCopyEndpoint" section
  restructured under unified "Postback Copy Endpoints — SKAN vs AAK"
  header with comparison table

### Fixed
- Final MuviAI residue in `WORKFLOW.md` (`MuviConfig/...` → `Config/...`)

### Frontmatter
- `metadata.version`: 1.1.0 → 1.2.0

## [1.1.0] — 2026-05-07

Major review iteration. Three parallel sub-agent reviews surfaced 24 findings
across technical accuracy, cross-reference integrity, and practical usability.
This release addresses all CRITICAL and most HIGH-priority items.

### Added
- **`WORKFLOW.md`** — 5-stage operating sequence (CONTEXT → ROUTE → DIAGNOSE
  → ACT → VERIFY) plus 5 ready-made multi-stage playbooks (post-ship attribution
  drop, pre-launch new app, ASA + AppsFlyer audit, Meta AEM not selectable,
  SKAN→AAK migration regression)
- **`README.md`** — public-facing project documentation with use cases,
  diagnostic examples, FAQ, and contributing guide
- **`LICENSE`** — MIT license file
- AdServices API integration section (`AAAttribution.attributionToken()`) in
  `apple-ads-audit.md` — fixes the most common cause of "80% Apple Ads installs
  show as Organic"
- iOS 18 `PostbackUpdate` API documentation in `adattributionkit-and-skan.md`
- AdAttributionKit re-engagement attribution flow (handleTap with
  reengagementURL, conversionTypes, monthly/yearly limits)
- SKAN→AAK migration regression failure mode (Failure Mode 6)
- Multi-window CV encoding strategy for subscription apps (preferred over
  single-window bit-packing)
- React Native + Expo snippets for Adjust + AppsFlyer + expo-tracking-transparency
- App Review rejection patterns section in `consent-gating.md` (incentive ban,
  effective-deny pre-prompts, vague third-party language, modal stacking)
- Apple Privacy Manifest required-reason API codes table (UserDefaults,
  FileTimestamp, SystemBootTime, DiskSpace, ActiveKeyboards)
- Maximize Conversions GA (Feb 2026) note in apple-ads-audit
- Custom Product Pages cap raised to 70 (Oct 2025) note
- Meta CAPI extinfo 16-position positional array reference table
- Diagnostic script checks 8b (capture-protection silent-defer) and 8c (SDK
  init order) — catches known production bug patterns
- Cross-references back-linking from `att-timing-and-events.md` and
  `consent-gating.md` to `symptom-to-cause.md` for lateral discoverability
- Apple Ads audit ↔ pre-launch checklist cross-reference

### Changed
- **Adjust v5 init API** — corrected from `Adjust.appDidLaunch()` (v4) to
  `Adjust.initSdk()` (v5). The v4 API name was a no-op in v5 and would have
  caused install events to never send.
- **`enableFirstSessionDelay`** — corrected from property assignment to method
  call: `adjustConfig?.enableFirstSessionDelay()` (was incorrectly shown as
  `= true`)
- **`attConsentWaitingInterval` max** — corrected from "120 native iOS / 360
  Air SDK" to "max 360 seconds (Adjust iOS native SDK)"
- **Diagnostic script empty-Info.plist false-positive** — fixed: previous
  version reported "✓ found" when no Info.plist existed in project
- **Diagnostic script SDK detection logic** — refactored to `detect_sdk()`
  helper function; previous chained `||`/`&&` had logic bug where pod-only
  projects silently missed detection
- **AASA validator URL** — Apple deprecated `search.developer.apple.com/appsearch-validation-tool`;
  replaced with Branch.io's public validator + Xcode Devices alternative
- **`SKAdNetwork.registerAppForAdNetworkAttribution`** — now explicitly
  documented as deprecated (since iOS 15.4); replaced with SKAN 4 API
- IDFA caching guidance corrected from "re-fetch per session" to "do not cache;
  read fresh at event-send time"

### Frontmatter
- `metadata.version`: 1.0.0 → 1.1.0
- `metadata.updated`: 2026-05-07 (new field)

## [1.0.0] — 2026-05-07

Initial release. Merge of three upstream community skills plus production
incident learnings.

### Sources merged
- `AgriciDaniel/claude-ads → ads-apple` (Apple Ads audit framework)
- `dpearson2699/swift-ios-skills → adattributionkit` (AdAttributionKit reference)
- `mukul975/Privacy-Data-Protection-Skills → managing-mobile-app-consent` (ATT
  4-state matrix, per-SDK consent propagation)

### Initial scope
- ATT 4-state behavior matrix
- 3-layer iOS attribution model (deterministic / SKAN+AAK / probabilistic)
- 7 reference files covering ATT timing, consent gating, AAK/SKAN, Meta AEM,
  Apple Ads audit, pre-launch checklist, symptom triage
- Static analysis script with 10 baseline checks
- Decision tree routing in SKILL.md

## [Unreleased]

### Possible additions
- Branch.io specific gotchas (`branch_referrable` flag, deferred deep link sandbox)
- Singular SKAN Decoder pattern documentation
- Conversions API server-side flow for Meta/TikTok
- Firebase + GA4 attribution consolidated reference
- iOS 26 ATT persistence change documentation (when Apple confirms)

[1.2.0]: https://github.com/Rylaa/ios-marketing-att-skill/releases/tag/v1.2.0
[1.1.0]: https://github.com/Rylaa/ios-marketing-att-skill/releases/tag/v1.1.0
[1.0.0]: https://github.com/Rylaa/ios-marketing-att-skill/releases/tag/v1.0.0
[Unreleased]: https://github.com/Rylaa/ios-marketing-att-skill/compare/v1.2.0...HEAD
