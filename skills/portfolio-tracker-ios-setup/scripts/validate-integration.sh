#!/bin/bash
# Validates Dezerv Portfolio Tracker SDK integration in an iOS project.
# Run from the project root: bash scripts/validate-integration.sh

set -euo pipefail

PASS=0
FAIL=0
WARN=0

pass() { echo "  ✓ $1"; ((PASS++)); }
fail() { echo "  ✗ $1"; ((FAIL++)); }
warn() { echo "  ⚠ $1"; ((WARN++)); }

echo "=== Dezerv SDK iOS Integration Validator ==="
echo ""

# 1. SPM dependency
echo "[1/7] Swift Package dependency"
if grep -rq "portfolio-sdk-ios" --include="*.swift" --include="*.resolved" --include="Package.swift" . 2>/dev/null || \
   grep -rq "portfolio-sdk-ios" --include="*.pbxproj" . 2>/dev/null; then
  pass "portfolio-sdk-ios found in package references"
else
  fail "portfolio-sdk-ios not found — add the SPM dependency first"
fi

# 2. Entry point exists
echo "[2/7] App entry point"
ENTRY_FILE=$(grep -rl "@main" --include="*.swift" . 2>/dev/null | head -1)
if [ -n "$ENTRY_FILE" ]; then
  pass "Entry point found: $ENTRY_FILE"
else
  ENTRY_FILE=$(grep -rl "@UIApplicationMain" --include="*.swift" . 2>/dev/null | head -1)
  if [ -n "$ENTRY_FILE" ]; then
    pass "Entry point found (UIKit): $ENTRY_FILE"
  else
    fail "No @main or @UIApplicationMain found"
  fi
fi

# 3. Warmup in entry point only
echo "[3/7] SDK warmup placement"
INIT_COUNT=$(grep -rn "DezervSDK.shared.initialize" --include="*.swift" . 2>/dev/null | wc -l | tr -d ' ')
if [ "$INIT_COUNT" -eq 0 ]; then
  warn "DezervSDK.shared.initialize not found — warmup is recommended"
elif [ "$INIT_COUNT" -eq 1 ]; then
  INIT_FILE=$(grep -rl "DezervSDK.shared.initialize" --include="*.swift" . 2>/dev/null | head -1)
  if [ -n "$ENTRY_FILE" ] && [ "$INIT_FILE" = "$ENTRY_FILE" ]; then
    pass "Warmup called once, in the entry point ($INIT_FILE)"
  else
    fail "Warmup is in $INIT_FILE but entry point is $ENTRY_FILE — move it to the entry point"
  fi
else
  fail "DezervSDK.shared.initialize called $INIT_COUNT times — should be exactly once"
  grep -rn "DezervSDK.shared.initialize" --include="*.swift" . 2>/dev/null | sed 's/^/    /'
fi

# 4. Builder + DezervSDKView not in entry point
echo "[4/7] Builder/View placement"
if [ -n "$ENTRY_FILE" ]; then
  if grep -q "DezervSDK.Builder" "$ENTRY_FILE" 2>/dev/null; then
    fail "DezervSDK.Builder is in the entry point ($ENTRY_FILE) — move it to a View or ViewController"
  else
    pass "DezervSDK.Builder is not in the entry point"
  fi
else
  warn "Cannot check — no entry point found"
fi

# 5. dispose() exists
echo "[5/7] Cleanup (dispose)"
if grep -rq "\.dispose()" --include="*.swift" . 2>/dev/null; then
  pass "dispose() call found"
else
  fail "No dispose() call found — SDK resources won't be cleaned up on dismissal"
fi

# 6. Face ID plist
echo "[6/7] Info.plist Face ID key"
if grep -rq "NSFaceIDUsageDescription" --include="*.plist" . 2>/dev/null; then
  pass "NSFaceIDUsageDescription present"
else
  fail "NSFaceIDUsageDescription missing from Info.plist"
fi

# 7. No hardcoded tokens
echo "[7/7] Hardcoded token check"
TOKEN_LINES=$(grep -rn "partnerAuthToken" --include="*.swift" . 2>/dev/null | grep -v "PARTNER_AUTH_TOKEN" | grep -v "// " | grep -v "func \|var \|let .*:" || true)
if [ -z "$TOKEN_LINES" ]; then
  pass "No suspicious hardcoded token values"
else
  warn "Review these lines for hardcoded tokens:"
  echo "$TOKEN_LINES" | sed 's/^/    /'
fi

# Summary
echo ""
echo "=== Results: $PASS passed, $FAIL failed, $WARN warnings ==="
if [ "$FAIL" -gt 0 ]; then
  echo "Fix the failures above before proceeding."
  exit 1
else
  echo "Integration looks correct."
  exit 0
fi
