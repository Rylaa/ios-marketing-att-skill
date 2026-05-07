#!/usr/bin/env bash
# diagnose.sh — quick static-analysis pass for iOS marketing+ATT health
# Run from project root. Greps for common anti-patterns.
#
# Usage: ./diagnose.sh [project-root]

set -euo pipefail

ROOT="${1:-.}"
cd "$ROOT"

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

pass()  { echo -e "${GREEN}✓${NC} $1"; }
warn()  { echo -e "${YELLOW}⚠${NC} $1"; }
fail()  { echo -e "${RED}✗${NC} $1"; }
info()  { echo "  → $1"; }

echo "=== iOS Marketing + ATT Pipeline Diagnosis ==="
echo "Root: $(pwd)"
echo

# ============================================================
# CHECK 1: Info.plist contains NSUserTrackingUsageDescription
# ============================================================
echo "[1/10] NSUserTrackingUsageDescription"
PLISTS=$(find . -name "Info.plist" -not -path "*/Pods/*" -not -path "*/build/*" 2>/dev/null)
if [ -z "$PLISTS" ]; then
    fail "no Info.plist files found in project"
elif echo "$PLISTS" | xargs grep -l "NSUserTrackingUsageDescription" >/dev/null 2>&1; then
    pass "found in Info.plist"
else
    fail "missing — ATT prompt will crash"
    info "Add NSUserTrackingUsageDescription to Info.plist"
fi
echo

# ============================================================
# CHECK 2: SKAdNetworkItems present
# ============================================================
echo "[2/10] SKAdNetworkItems"
if [ -z "$PLISTS" ]; then
    warn "skipped — no Info.plist found"
elif echo "$PLISTS" | xargs grep -l "SKAdNetworkItems" >/dev/null 2>&1; then
    pass "SKAdNetworkItems present"
else
    fail "missing — no SKAN postbacks possible"
    info "Add SKAdNetworkItems with all ad partner IDs"
fi
echo

# ============================================================
# CHECK 3: PrivacyInfo.xcprivacy exists
# ============================================================
echo "[3/10] PrivacyInfo.xcprivacy"
if find . -name "PrivacyInfo.xcprivacy" -not -path "*/Pods/*" 2>/dev/null | grep -q .; then
    pass "PrivacyInfo.xcprivacy exists"
else
    fail "missing — App Review will reject (iOS 17+)"
fi
echo

# ============================================================
# CHECK 4: AdAttributionKit Info.plist key (iOS 17.4+)
# ============================================================
echo "[4/10] AdAttributionKit"
if [ -z "$PLISTS" ]; then
    warn "skipped — no Info.plist found"
elif echo "$PLISTS" | xargs grep -l "AttributionCopyEndpoint" >/dev/null 2>&1; then
    pass "AttributionCopyEndpoint configured"
else
    warn "no AttributionCopyEndpoint — server-side postback mirror not enabled"
fi
echo

# ============================================================
# CHECK 5: AppsFlyer waitForATTUserAuthorization
# ============================================================
echo "[5/10] AppsFlyer ATT wait config"
if grep -rln "waitForATTUserAuthorization\|timeToWaitForATTUserAuthorization" \
   --include="*.swift" --include="*.m" --include="*.ts" --include="*.tsx" --include="*.js" \
   . 2>/dev/null | grep -v "/Pods/\|/node_modules/\|/build/" | head -5 >/tmp/af_check; then
    if [ -s /tmp/af_check ]; then
        pass "AppsFlyer wait config found"
        cat /tmp/af_check | sed 's/^/    /'
    else
        warn "AppsFlyer SDK not detected — skip if not using"
    fi
fi
echo

# ============================================================
# CHECK 6: Adjust attConsentWaitingInterval
# ============================================================
echo "[6/10] Adjust ATT wait config"
ADJ_HITS=$(grep -rln "attConsentWaitingInterval\|setAttConsentWaitingInterval" \
    --include="*.swift" --include="*.m" --include="*.ts" --include="*.tsx" --include="*.js" \
    . 2>/dev/null | grep -v "/Pods/\|/node_modules/\|/build/" | head -5)
if [ -n "$ADJ_HITS" ]; then
    pass "Adjust attConsentWaitingInterval found"
    echo "$ADJ_HITS" | sed 's/^/    /'
else
    warn "no attConsentWaitingInterval — skip if not using Adjust"
fi
echo

# ============================================================
# CHECK 7: ATTrackingManager request actually called
# ============================================================
echo "[7/10] ATT prompt invocation"
ATT_HITS=$(grep -rln "requestTrackingAuthorization\|requestTrackingPermissionsAsync" \
    --include="*.swift" --include="*.m" --include="*.ts" --include="*.tsx" --include="*.js" \
    . 2>/dev/null | grep -v "/Pods/\|/node_modules/\|/build/" | head -5)
if [ -n "$ATT_HITS" ]; then
    pass "ATT request found"
    echo "$ATT_HITS" | sed 's/^/    /'
else
    fail "no ATT request call — IDFA permanently zero"
fi
echo

# ============================================================
# CHECK 8: trackEvent calls + ATT-gating heuristic
# ============================================================
echo "[8/10] trackEvent / logEvent call sites + ATT-gating"
EVENT_HITS_ALL=$(grep -rn "Adjust\.trackEvent\|AppsFlyerLib.*sendEvent\|AppEvents\.shared\.logEvent\|appsFlyer\.logEvent" \
    --include="*.swift" --include="*.m" --include="*.ts" --include="*.tsx" --include="*.js" \
    . 2>/dev/null | grep -v "/Pods/\|/node_modules/\|/build/" || true)
if [ -n "$EVENT_HITS_ALL" ]; then
    EVENT_COUNT=$(echo "$EVENT_HITS_ALL" | wc -l | tr -d ' ')
    # Heuristic: check whether ANY file containing trackEvent also references an ATT resolver
    UNGATED=0
    while IFS=: read -r file _; do
        [ -z "$file" ] && continue
        if ! grep -q "AttResolver\|requestTrackingAuthorization\|requestTrackingPermissions\|attStatus\|trackingAuthorizationStatus" "$file" 2>/dev/null; then
            UNGATED=$((UNGATED + 1))
        fi
    done <<< "$(echo "$EVENT_HITS_ALL" | head -20)"
    if [ "$UNGATED" -gt 0 ]; then
        fail "$EVENT_COUNT trackEvent/logEvent call sites; ~$UNGATED file(s) lack any ATT-gating reference"
    else
        warn "$EVENT_COUNT trackEvent/logEvent call sites — manual review still recommended"
    fi
    echo "$EVENT_HITS_ALL" | head -5 | sed 's/^/    /'
    if [ "$EVENT_COUNT" -gt 5 ]; then
        info "($EVENT_COUNT total — showing first 5)"
    fi
else
    info "no event tracking calls found (or different SDK pattern used)"
fi
echo

# ============================================================
# CHECK 8b: Capture-protection silent-defer (known production bug pattern)
# ============================================================
echo "[8b] Capture-protection ATT defer"
CAP_HITS=$(grep -rln "isCaptured" --include="*.swift" --include="*.m" \
    . 2>/dev/null | grep -v "/Pods/\|/build/" || true)
if [ -n "$CAP_HITS" ]; then
    while IFS= read -r file; do
        if grep -q "requestTrackingAuthorization" "$file" 2>/dev/null; then
            fail "$file uses isCaptured near requestTrackingAuthorization — ATT may be silently deferred"
            info "Add a hard timeout fallback so prompt fires regardless of capture state"
        fi
    done <<< "$CAP_HITS"
fi
echo

# ============================================================
# CHECK 8c: Init order — wait config must precede start()/initSdk
# ============================================================
echo "[8c] SDK init order (waitFor* config BEFORE start)"
ORDER_FILES=$(grep -rln "AppsFlyerLib.shared().start\|Adjust.initSdk\|Adjust.appDidLaunch" \
    --include="*.swift" --include="*.m" \
    . 2>/dev/null | grep -v "/Pods/\|/build/" || true)
if [ -n "$ORDER_FILES" ]; then
    while IFS= read -r file; do
        # Get line numbers of init vs wait config
        WAIT_LINE=$(grep -n "waitForATTUserAuthorization\|attConsentWaitingInterval\|setAttConsentWaitingInterval" "$file" 2>/dev/null | head -1 | cut -d: -f1)
        START_LINE=$(grep -n "AppsFlyerLib.shared().start\|Adjust.initSdk\|Adjust.appDidLaunch" "$file" 2>/dev/null | head -1 | cut -d: -f1)
        if [ -n "$WAIT_LINE" ] && [ -n "$START_LINE" ] && [ "$WAIT_LINE" -gt "$START_LINE" ]; then
            fail "$file: wait config (line $WAIT_LINE) AFTER init (line $START_LINE) — must precede"
        fi
    done <<< "$ORDER_FILES"
fi
echo

# ============================================================
# CHECK 9: SKAdNetwork updateConversionValue called
# ============================================================
echo "[9/10] SKAN/AAK conversion value updates"
CV_HITS=$(grep -rln "updateConversionValue\|updatePostbackConversionValue\|registerAppForAdNetworkAttribution" \
    --include="*.swift" --include="*.m" \
    . 2>/dev/null | grep -v "/Pods/\|/build/" | head -5)
if [ -n "$CV_HITS" ]; then
    pass "conversion value update calls found"
    echo "$CV_HITS" | sed 's/^/    /'
else
    warn "no updateConversionValue calls — SKAN postbacks won't carry CV data"
    info "If MMP handles SKAN automatically, this is OK"
fi
echo

# ============================================================
# CHECK 10: Marketing SDKs detected
# ============================================================
echo "[10/10] Marketing SDK inventory"
DETECTED=()

detect_sdk() {
    local name="$1" pod_dir="$2" grep_pattern="$3"
    if [ -d "$pod_dir" ]; then
        DETECTED+=("$name")
        return
    fi
    if grep -rln "$grep_pattern" --include="*.swift" --include="*.m" --include="*.ts" --include="*.tsx" --include="*.js" \
        . 2>/dev/null | grep -v "/node_modules/\|/Pods/\|/build/" | head -1 >/dev/null; then
        DETECTED+=("$name")
    fi
}

detect_sdk "AppsFlyer"  "Pods/AppsFlyerFramework"      "import AppsFlyerLib\|react-native-appsflyer"
detect_sdk "Adjust"     "Pods/Adjust"                  "import AdjustSdk\|import Adjust\|react-native-adjust"
detect_sdk "Branch"     "Pods/Branch-SDK"              "import Branch\|react-native-branch"
detect_sdk "Singular"   "Pods/Singular-SDK"            "import Singular\|react-native-singular"
detect_sdk "Meta SDK"   "Pods/FBSDKCoreKit"            "import FBSDKCoreKit\|import FacebookSDK\|react-native-fbsdk"
detect_sdk "Firebase"   "Pods/FirebaseAnalytics"       "import FirebaseAnalytics\|import Firebase"
detect_sdk "AdMob"      "Pods/Google-Mobile-Ads-SDK"   "import GoogleMobileAds"

if [ ${#DETECTED[@]} -gt 0 ]; then
    pass "marketing SDKs detected:"
    for sdk in "${DETECTED[@]}"; do
        info "$sdk"
    done
else
    warn "no marketing SDKs detected — verify project has them, or you're not running paid UA yet"
fi
echo

# ============================================================
# SUMMARY
# ============================================================
echo "=== Done ==="
echo
echo "Read references/symptom-to-cause.md for diagnosis based on the warnings above."
echo
