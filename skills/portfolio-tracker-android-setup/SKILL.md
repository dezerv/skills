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

## Required `partnerUserMeta` fields (checklist)

| Field | Required | Notes |
|-------|----------|--------|
| `partner_category` | Yes | Fixed enum values; do not rename |
| `partner_symbol` | Yes | `""` on `homepage` / `news` |
| `partner_page_title` | Yes | |
| `partner_image_text` | Yes | |
| `partner_keywords` | When `news` | Array of article tags |
| `partner` | Yes | Partner id |
| `session_id` | Yes | |
| `schema_version` | Yes | Send `"2.0"` |
| `partner_source` | Recommended | e.g. `home_tab` |
| `partner_page_url` | Recommended | Launch page URL |
| `partner_campaign` | Recommended | Campaign id |
| `phone` | No | |
| `pan` | No | |
| `deeplink` | No | In-SDK route |
| `sdkMetrics` | No | `startTime` / `endTime` of `/auth/token` |
| `partner_section_name` | No | e.g. `Top Gainers` |
| `partner_cta_copy` | No | CTA label text |
| `partner_cta_position` | No | e.g. `hero`, `inline`, `sticky` |
| `partner_medium` | No | e.g. `app`, `whatsapp` |

## Error codes

| Code | Description |
|------|-------------|
| `sdk_error` | An unexpected SDK error occurred |
| `network_error` | Network connectivity issues |
| `unknown_error` | Unknown error occurred |

## Verification

1. Gradle sync succeeds; `in.dezerv:portfolio_tracker_sdk:0.8.6` resolves
2. App builds on API 33+ device/emulator
3. With a real `partnerAuthToken`, `show()` loads the SDK UI
4. Logcat receives `sdkInitializationSuccess` (or a clear `sdkInitializationError`)
5. Exit closes the host screen / navigates correctly

## Troubleshooting

| Symptom | Check |
|---------|--------|
| Dependency not found | `google()` + `mavenCentral()`; version `0.8.6` |
| Crash / no UI below API 33 | Gate on `TIRAMISU`; show fallback message |
| Auth / blank SDK | Invalid or missing `partnerAuthToken`; confirm backend JWT |
| Personalization wrong | Required meta fields missing or wrong `partner_category` |
| Warmup slow / no benefit | Pass `environment`; match theme between warmup and `DezervSDKConfig` |
| Release minify issues | Check ProGuard rules below |

## ProGuard (release minify)

As of 0.8.6 the SDK ships narrower consumer rules (`-keepclassmembers` instead of `-keep class *` for Gson). If your own classes use `@SerializedName`, ensure your ProGuard rules preserve them. For the SDK itself:

```
-keep class in.dezerv.portfolio_tracker_sdk.** { *; }
-keepclassmembers class in.dezerv.portfolio_tracker_sdk.** { *; }
```

## Keyboard behaviour (0.8.5+)

The SDK automatically resizes its WebView when the soft keyboard opens. If you embed the SDK in a custom container with its own keyboard handling, be aware of this — it may affect your layout.

## Do not

- Do not invent a `PortfolioTrackerSDK` / username-password init API — use `DezervSDK` + `DezervSDKConfig`
- Do not hardcode production JWTs or PII in source control
- Do not skip `DezervSDKView` + `withView` + `show()` — dependency alone is not enough
