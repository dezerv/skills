#!/bin/bash
# Validates Dezerv Portfolio Tracker SDK integration in an Android project.
# Run from the project root: bash scripts/validate-integration.sh

set +e

PASS=0
FAIL=0
WARN=0

pass() { echo "  ✓ $1"; PASS=$((PASS + 1)); }
fail() { echo "  ✗ $1"; FAIL=$((FAIL + 1)); }
warn() { echo "  ⚠ $1"; WARN=$((WARN + 1)); }

echo "=== Dezerv SDK Android Integration Validator ==="
echo ""

# 1. Gradle dependency
echo "[1/8] Gradle dependency"
if grep -rq "portfolio_tracker_sdk" --include="build.gradle*" . 2>/dev/null; then
  pass "portfolio_tracker_sdk found in Gradle files"
  GRADLE_FILE=$(grep -rl "portfolio_tracker_sdk" --include="build.gradle*" . 2>/dev/null | head -1)
  echo "    in: $GRADLE_FILE"
else
  fail "portfolio_tracker_sdk not found in any build.gradle — add the dependency first"
fi

# 2. Maven Central in repositories
echo "[2/8] Maven Central repository"
if grep -rq "mavenCentral()" --include="build.gradle*" --include="settings.gradle*" . 2>/dev/null; then
  pass "mavenCentral() found in Gradle config"
else
  fail "mavenCentral() not found — SDK won't resolve"
fi

# 3. Application class
echo "[3/8] Application class"
APP_CLASS=$(grep -rln "class.*:.*Application()" --include="*.kt" . 2>/dev/null | head -1)
if [ -z "$APP_CLASS" ]; then
  APP_CLASS=$(grep -rln "extends Application" --include="*.java" . 2>/dev/null | head -1)
fi
if [ -n "$APP_CLASS" ]; then
  pass "Application class found: $APP_CLASS"
else
  fail "No custom Application class found — create one for SDK warmup"
fi

# 4. Application registered in manifest
echo "[4/8] Application registered in manifest"
MANIFEST=$(find . -name "AndroidManifest.xml" -not -path "*/build/*" | head -1)
if [ -n "$MANIFEST" ]; then
  if grep -q 'android:name=.*[Aa]pplication' "$MANIFEST" 2>/dev/null; then
    pass "Application class registered in manifest"
  else
    fail "No android:name on <application> tag in $MANIFEST"
  fi
else
  fail "No AndroidManifest.xml found"
fi

# 5. Warmup in Application class only
echo "[5/8] SDK warmup placement"
INIT_COUNT=$(grep -rn "DezervSDK.initialize" --include="*.kt" --include="*.java" . 2>/dev/null | grep -v '^\s*//' | grep -v '^\s*\*' | grep -v '/build/' | wc -l | tr -d ' ')
if [ "$INIT_COUNT" -eq 0 ]; then
  warn "DezervSDK.initialize not found — warmup is recommended"
elif [ "$INIT_COUNT" -eq 1 ]; then
  INIT_FILE=$(grep -rl "DezervSDK.initialize" --include="*.kt" --include="*.java" . 2>/dev/null | grep -v '/build/' | head -1)
  if [ -n "$APP_CLASS" ] && [ "$INIT_FILE" = "$APP_CLASS" ]; then
    pass "Warmup called once, in the Application class ($INIT_FILE)"
  else
    fail "Warmup is in $INIT_FILE but Application class is $APP_CLASS — move it"
  fi
else
  fail "DezervSDK.initialize called $INIT_COUNT times — should be exactly once"
  grep -rn "DezervSDK.initialize" --include="*.kt" --include="*.java" . 2>/dev/null | sed 's/^/    /'
fi

# 6. Builder + show() not in Application class
echo "[6/8] Builder/show() placement"
if [ -n "$APP_CLASS" ]; then
  if grep -q "DezervSDK.Builder" "$APP_CLASS" 2>/dev/null; then
    fail "DezervSDK.Builder is in the Application class — move it to an Activity or Fragment"
  else
    pass "DezervSDK.Builder is not in the Application class"
  fi
else
  warn "Cannot check — no Application class found"
fi

# 7. DezervSDKView in layout
echo "[7/8] DezervSDKView in layout"
if grep -rq "DezervSDKView" --include="*.xml" . 2>/dev/null; then
  pass "DezervSDKView found in layout XML"
  grep -rn "DezervSDKView" --include="*.xml" . 2>/dev/null | sed 's/^/    /'
else
  fail "DezervSDKView not found in any layout XML"
fi

# 8. No hardcoded tokens
echo "[8/8] Hardcoded token check"
TOKEN_LINES=$(grep -rn "partnerAuthToken" --include="*.kt" --include="*.java" . 2>/dev/null | grep -v "PARTNER_AUTH_TOKEN" | grep -v "// " | grep -v "fun \|val \|var " || true)
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
