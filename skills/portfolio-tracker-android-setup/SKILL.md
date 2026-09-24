---
name: portfolio-tracker-android-setup
description: >
  Set up Portfolio Tracker (Dezerv) SDK in an Android project — Gradle
  dependency, permissions, partner auth token, user metadata, DezervSDKView,
  Builder show flow, optional warmup, and events. Use when the user asks to
  integrate, set up, or configure the Portfolio Tracker / Dezerv SDK for
  Android, or mentions "portfolio tracker android", "dezerv android sdk",
  or "portfolio sdk gradle".
---

# Portfolio Tracker SDK — Android Setup

Integrate the Dezerv Portfolio Tracker SDK into the **partner app** (not the Skills or docs repos). Follow steps in order. After each step, verify before continuing.

Canonical docs (prefer these if anything conflicts):
- https://dezerv.github.io/portfolio-tracker-sdk-docs/current/android/installation
- https://dezerv.github.io/portfolio-tracker-sdk-docs/current/android/usage
- https://dezerv.github.io/portfolio-tracker-sdk-docs/current/android/events

## Prerequisites

Confirm the host app has:
- Android Studio (latest)
- Gradle 8.0+
- **minSdk / runtime: Android 13 (API 33)+** for showing the SDK (`Build.VERSION_CODES.TIRAMISU`)
- Activity must be `FragmentActivity` or subclass (e.g. `AppCompatActivity`)
- A **backend-issued `partnerAuthToken`** (JWT). Do not invent credentials; ask the partner for their Dezerv token endpoint / sample token.

## Before you start — credentials

The SDK does **not** use username/password in-app. You need:

1. `partnerAuthToken` — JWT from the partner backend (Dezerv `/auth/token` flow)
2. `partnerUserMeta` — JSON with required personalization + session fields (below)

If the user has no token yet, stop after dependency/permissions and tell them to obtain a partner auth token from Dezerv before calling `Builder` / `show()`.

## Step 1: Add the SDK dependency

Current published version: **0.8.6** (Maven Central).

### Kotlin DSL (recommended)

In `settings.gradle.kts`, ensure Maven Central is available:

```kotlin
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}
```

In the app module `build.gradle.kts`:

```kotlin
dependencies {
    implementation("in.dezerv:portfolio_tracker_sdk:0.8.6")
}
```

### Groovy

In the app `build.gradle`:

```groovy
repositories {
    google()
    mavenCentral()
}

dependencies {
    implementation 'in.dezerv:portfolio_tracker_sdk:0.8.6'
}
```

Sync Gradle (`File > Sync Now` or `./gradlew :app:dependencies`).

## Step 2: Permissions

In `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<!-- Optional to declare explicitly; SDK merges USE_BIOMETRIC automatically -->
<uses-permission android:name="android.permission.USE_BIOMETRIC" />
```

## Step 2b: Locate integration points

Before writing any code, discover the partner's project structure so the SDK init lands in the right place.

### Find the Application class

```bash
grep -rn "class.*Application()" --include="*.kt" --include="*.java" .
grep -rn "android:name=" --include="AndroidManifest.xml" . | grep -i "application"
```

The warmup (`DezervSDK.initialize`) **must** go in the `Application.onCreate()`. If no custom Application class exists, you'll need to create one and register it in the manifest.

### Check for existing SDK integration

```bash
grep -rn "import.*dezerv" --include="*.kt" --include="*.java" .
grep -rn "DezervSDK" --include="*.kt" --include="*.java" .
```

If results are found, the SDK may already be integrated. Review the existing integration before adding duplicate code. Ask the user whether they want to update or replace the existing setup.

### Find the hosting Activity/Fragment

```bash
grep -rn "AppCompatActivity\|FragmentActivity" --include="*.kt" --include="*.java" .
```

Identify which Activity or Fragment will host `DezervSDKView`. If the partner already has a screen for it, modify that. If not, ask where they want the SDK presented.

### Check the layout files

```bash
grep -rn "DezervSDKView\|dezervSDKView" --include="*.xml" .
```

If an existing layout already includes `DezervSDKView`, use that layout rather than creating a new one.

### Confirm the Gradle module

Check which module the app target lives in — the SDK dependency must be in the same module's `build.gradle.kts` (or `build.gradle`):

```bash
find . -name "build.gradle.kts" -o -name "build.gradle" | head -10
grep -rn "portfolio_tracker_sdk" --include="build.gradle*" .
```

## Step 3 (recommended): Warmup at app start

Call early (e.g. `Application.onCreate`). Non-blocking. Match `theme` / `viewType` with what you use later in `DezervSDKConfig`.

```kotlin
import android.app.Application
import android.os.Build
import `in`.dezerv.portfolio_tracker_sdk.DezervSDK
import `in`.dezerv.portfolio_tracker_sdk.core.DezervSDKEnvironment
import `in`.dezerv.portfolio_tracker_sdk.core.DezervSDKInitConfig
import `in`.dezerv.portfolio_tracker_sdk.core.DezervSDKTheme
import `in`.dezerv.portfolio_tracker_sdk.core.DezervViewType

class MyApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            DezervSDK.initialize(
                context = this,
                dezervSDKInitConfig = DezervSDKInitConfig(
                    theme = DezervSDKTheme.light,
                    viewType = DezervViewType.FULL_VIEW,
                    isDebug = BuildConfig.DEBUG,
                    environment = DezervSDKEnvironment.PRODUCTION // or PREPROD
                )
            )
        }
    }
}
```

Register `MyApplication` in the manifest. If warmup fails, the SDK still works; first open may be slower. Listen for `sdkWarmupComplete` to confirm warmup finished.

## Step 4: Add `DezervSDKView` to the layout

```xml
<in.dezerv.portfolio_tracker_sdk.DezervSDKView
    android:id="@+id/dezervSDKView"
    android:layout_width="match_parent"
    android:layout_height="match_parent" />
```

## Step 5: Build config, bind view, show

```kotlin
import android.os.Build
import android.os.Bundle
import android.util.Log
import androidx.appcompat.app.AppCompatActivity
import `in`.dezerv.portfolio_tracker_sdk.DezervSDK
import `in`.dezerv.portfolio_tracker_sdk.DezervSDKView
import `in`.dezerv.portfolio_tracker_sdk.core.DezervSDKConfig
import `in`.dezerv.portfolio_tracker_sdk.core.DezervSDKEvent
import `in`.dezerv.portfolio_tracker_sdk.core.DezervSDKInitConfig
import `in`.dezerv.portfolio_tracker_sdk.core.DezervSDKTheme
import `in`.dezerv.portfolio_tracker_sdk.core.DezervViewType
import org.json.JSONObject

class PortfolioActivity : AppCompatActivity() {
    private var dezervSDKInstance: DezervSDK? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_portfolio)

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            // SDK requires Android 13+
            return
        }

        val dezervSDKView: DezervSDKView = findViewById(R.id.dezervSDKView)

        // Replace with JWT from partner backend
        val authToken = "PARTNER_AUTH_TOKEN"

        val userMeta = JSONObject().apply {
            // Session / analytics (required)
            put("session_id", "REPLACE_SESSION_ID")
            put("schema_version", "2.0")
            put("partner", "REPLACE_PARTNER_ID") // e.g. moneycontrol

            // Personalization (required)
            put("partner_category", "stock") // stock|mutual_fund|index|commodity|ipo|news|homepage|comms|portfolio
            put("partner_symbol", "RELIANCE") // empty string when category is homepage or news
            put("partner_page_title", "Reliance Industries Share Price")
            put("partner_image_text", "Track your portfolio in one place")
            // put("partner_keywords", listOf("tag1")) // required when partner_category == news

            // Recommended attribution
            put("partner_source", "home_tab")
            put("partner_page_url", "https://partner.com/stocks/reliance-industries")
            put("partner_campaign", "example_campaign")

            // Optional
            // put("phone", "9898989898")
            // put("pan", "ABCDE1234F")
            // put("deeplink", "")
            // put("sdkMetrics", JSONObject().put("startTime", 0.0).put("endTime", 0.0))
            // put("partner_section_name", "Top Gainers")
            // put("partner_cta_copy", "Stop Guessing, Get wealth review by an Expert")
            // put("partner_cta_position", "hero") // hero|inline|sticky
            // put("partner_medium", "app") // app|whatsapp
        }

        val config = DezervSDKConfig(
            partnerAuthToken = authToken,
            partnerUserMeta = userMeta,
            theme = DezervSDKTheme.light, // or dark — match warmup
            viewType = DezervViewType.FULL_VIEW, // TAB_VIEW for fragments / nested UI
            isDebug = BuildConfig.DEBUG
        )

        dezervSDKInstance = DezervSDK.Builder(this)
            .setConfig(config)
            .withView(dezervSDKView)
            .withMessageListener { event, payload ->
                when (event) {
                    DezervSDKEvent.sdkInitializationSuccess ->
                        Log.d("DezervSDK", "initialized")
                    DezervSDKEvent.sdkInitializationError ->
                        Log.e("DezervSDK", "init error: ${payload?.optString("error")}")
                    DezervSDKEvent.sdkWarmupComplete ->
                        Log.d("DezervSDK", "warmup complete")
                    DezervSDKEvent.exit -> {
                        val errorCode = payload?.optString("errorCode")
                        if (errorCode == "sdk_error") {
                            // Re-initialize SDK with new auth token
                            Log.e("DezervSDK", "exit due to sdk_error — re-init needed")
                        } else {
                            finish()
                        }
                    }
                    DezervSDKEvent.userAuth ->
                        Log.d("DezervSDK", "userAuth: $payload")
                    DezervSDKEvent.setUserId ->
                        Log.d("DezervSDK", "userId: ${payload?.optString("userId")}")
                    DezervSDKEvent.onDeeplink ->
                        Log.d("DezervSDK", "deeplink: ${payload?.optString("link")}")
                    DezervSDKEvent.analytics ->
                        Log.d("DezervSDK", "analytics: $payload")
                    DezervSDKEvent.themeChange ->
                        Log.d("DezervSDK", "theme: ${payload?.optString("theme")}")
                    else -> Log.d("DezervSDK", "event=$event payload=$payload")
                }
            }
            .build()

        dezervSDKInstance?.show()
    }

    override fun onDestroy() {
        super.onDestroy()
        dezervSDKInstance = null
    }
}
```

To update the listener after build:

```kotlin
dezervSDKInstance?.setOnMessageListener { event, payload ->
    // Updated handler
}
```

### Fragments

Use `DezervViewType.TAB_VIEW`, cast `requireActivity()` to `FragmentActivity`, and clear the instance in `onDestroyView()`.

### Logout

When the partner user logs out of the host app:

```kotlin
DezervSDK.logout()
```

## Required `partnerUserMeta` fields

Read `references/user-meta-fields.md` for the full field table when constructing or debugging `partnerUserMeta`.

## Verification

### Build & runtime checks

1. Gradle sync succeeds; `in.dezerv:portfolio_tracker_sdk:0.8.6` resolves
2. App builds on API 33+ device/emulator
3. With a real `partnerAuthToken`, `show()` loads the SDK UI
4. Logcat receives `sdkInitializationSuccess` (or a clear `sdkInitializationError`)
5. Exit closes the host screen / navigates correctly

### Placement validation (run after all steps)

After writing code, verify correct placement:

1. **Warmup is in the Application class only** — confirm `DezervSDK.initialize` appears exactly once, inside `Application.onCreate()`:
   ```bash
   grep -rn "DezervSDK.initialize" --include="*.kt" --include="*.java" .
   ```
   Expected: one match, in the file identified in Step 2b. If found elsewhere (e.g. in an Activity), remove the duplicate.

2. **Application class is registered in the manifest**:
   ```bash
   grep -n "android:name=" --include="AndroidManifest.xml" -r . | grep -i "application"
   ```
   The `<application>` tag must have `android:name` pointing to the custom Application class.

3. **DezervSDKView is in a layout used by the hosting Activity**:
   ```bash
   grep -rn "DezervSDKView" --include="*.xml" .
   grep -rn "setContentView\|R.layout" --include="*.kt" --include="*.java" . | grep -i "portfolio\|dezerv\|sdk"
   ```
   The layout containing `DezervSDKView` must be the one inflated by the Activity that calls `Builder` + `show()`.

4. **Builder + show() are in an Activity/Fragment, not the Application class**:
   ```bash
   grep -rn "DezervSDK.Builder\|\.show()" --include="*.kt" --include="*.java" .
   ```
   These should be in the hosting Activity or Fragment, never in `Application.onCreate()`.

5. **No duplicate SDK views** — only one `DezervSDKView` per screen:
   ```bash
   grep -rn "DezervSDKView" --include="*.xml" --include="*.kt" --include="*.java" .
   ```

6. **No hardcoded tokens** — confirm placeholder strings are present, not real JWTs:
   ```bash
   grep -rn "partnerAuthToken" --include="*.kt" --include="*.java" .
   ```
   The value should be `"PARTNER_AUTH_TOKEN"` or fetched from a backend call, never a real token literal.

7. **API level gate exists** — confirm the `TIRAMISU` check wraps SDK calls:
   ```bash
   grep -rn "TIRAMISU\|Build.VERSION_CODES" --include="*.kt" --include="*.java" .
   ```

## Troubleshooting

Read `references/troubleshooting.md` if the build fails, the SDK shows a blank screen, or runtime errors appear.

## ProGuard (release minify)

As of 0.8.6 the SDK ships narrower consumer rules (`-keepclassmembers` instead of `-keep class *` for Gson). If your own classes use `@SerializedName`, ensure your ProGuard rules preserve them. For the SDK itself:

```
-keep class in.dezerv.portfolio_tracker_sdk.** { *; }
-keepclassmembers class in.dezerv.portfolio_tracker_sdk.** { *; }
```

## Keyboard behaviour (0.8.5+)

The SDK automatically resizes its WebView when the soft keyboard opens. If you embed the SDK in a custom container with its own keyboard handling, be aware of this — it may affect your layout.

## Gotchas

- The agent may try to create a `PortfolioTrackerSDK(username, password)` or similar init — **this API does not exist**. The only init path is `DezervSDK.initialize` (warmup) + `DezervSDK.Builder(activity)` + `DezervSDKConfig`. If the agent invents a different API shape, it's hallucinating.
- The agent may consider the Gradle dependency as "done" — it's not. The SDK does nothing until `Builder` + `withView` + `show()` are called with a configured `DezervSDKConfig`. Adding the dependency is step 1 of 5.
- `DezervSDKEnvironment.INTEGRATION` exists in the enum but is **Dezerv-internal only**. Never suggest it for partner apps — only `PRODUCTION` or `PREPROD`.
- The agent may put `DezervSDK.Builder` in the `Application.onCreate()` alongside warmup. Builder + `show()` belong in an Activity or Fragment, not in the Application class.
- `DezervSDK.initialize` should be called **exactly once** in `Application.onCreate()`. If the agent also adds it to an Activity, remove the duplicate.
- The Activity hosting `DezervSDKView` **must** extend `FragmentActivity` (or `AppCompatActivity`). If the agent creates a plain `Activity`, `Builder` will crash at runtime.
- The SDK requires **Android 13 (API 33)+** at runtime. All SDK calls must be gated with `Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU`. Without this check, the app will crash on older devices.
- Never hardcode real `partnerAuthToken` JWTs or PII (`phone`, `pan`) in source. Use placeholder values in code; fetch real tokens from the partner backend at runtime.

## Run validation

After completing all steps, run the automated validator from the project root:

```bash
bash scripts/validate-integration.sh
```

Fix any failures before considering the integration complete.
