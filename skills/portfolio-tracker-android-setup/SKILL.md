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

## Step 1: Discover the project structure

Before modifying anything, map the project so every change lands in the right file.

### 1a. Check for existing SDK integration

```bash
grep -rn "import.*dezerv" --include="*.kt" --include="*.java" .
grep -rn "DezervSDK" --include="*.kt" --include="*.java" .
```

If results are found, the SDK is already integrated. Review what exists and ask the user whether to update or replace it. Do **not** add duplicate init/builder code.

### 1b. Determine Kotlin DSL vs Groovy

```bash
find . -name "build.gradle.kts" -not -path "*/build/*" | head -5
find . -name "build.gradle" -not -path "*/build/*" -not -name "*.kts" | head -5
find . -name "settings.gradle*" -not -path "*/build/*"
```

- `.kts` files → Kotlin DSL syntax.
- `.gradle` files (no `.kts`) → Groovy syntax.

Identify the **app module's** build file (usually `app/build.gradle.kts` or `app/build.gradle`). Multi-module projects may have several — the SDK dependency goes in the module that contains the Activity hosting the SDK.

### 1c. Find the Application class

```bash
grep -rn "class.*:.*Application()" --include="*.kt" --include="*.java" . | grep -v "/build/"
grep -rn "android:name=" --include="AndroidManifest.xml" . | grep -v "/build/" | grep -i "application"
```

Read the matched Application class file. If no custom Application class exists, you'll create one in Step 4.

### 1d. Find the main AndroidManifest.xml

```bash
find . -name "AndroidManifest.xml" -not -path "*/build/*" | head -5
```

There may be several (app, libraries, test). The one in the **app module** (usually `app/src/main/AndroidManifest.xml`) is where permissions and the Application class are registered.

### 1e. Note the project's file/folder conventions

```bash
find . -name "*.kt" -not -path "*/build/*" -maxdepth 5 | head -20
```

Observe where the partner keeps their Activity/Fragment files (e.g. `ui/`, `features/`, `screens/`, or flat in the main package). Create the SDK hosting Activity following the same convention. The skill creates a dedicated `PortfolioActivity` — how the partner navigates to it (intent, nav component, etc.) is their decision.

The hosting Activity **must** extend `FragmentActivity` or `AppCompatActivity`.

## Step 2: Add the SDK dependency

Current published version: **0.8.6** (Maven Central).

### 2a. Ensure Maven Central is in repositories

Read the project's `settings.gradle.kts` (or `settings.gradle`). Check if `mavenCentral()` is already listed in the `repositories` block:

```bash
grep -n "mavenCentral" --include="settings.gradle*" --include="build.gradle*" -r . | grep -v "/build/"
```

If missing, **append** `mavenCentral()` to the existing `repositories` block — do not replace other repositories.

### 2b. Add the dependency to the app module

Read the app module's build file. Find the existing `dependencies` block and **append** the SDK line:

**Kotlin DSL** (`.kts`):
```kotlin
implementation("in.dezerv:portfolio_tracker_sdk:0.8.6")
```

**Groovy** (`.gradle`):
```groovy
implementation 'in.dezerv:portfolio_tracker_sdk:0.8.6'
```

Do not replace the dependencies block. Add the line alongside existing dependencies.

## Step 2c: Sync and download the dependency — MANDATORY

**Do not skip this step.** The dependency does not exist locally until Gradle resolves it.

```bash
./gradlew :app:dependencies --configuration implementation 2>&1 | grep -i "dezerv"
```

If `./gradlew` is not executable:
```bash
chmod +x ./gradlew && ./gradlew :app:dependencies --configuration implementation 2>&1 | grep -i "dezerv"
```

If the project uses a different app module name (not `app`), replace `:app:` with the correct module path found in Step 1b.

Wait for it to finish. **Verify the output shows `in.dezerv:portfolio_tracker_sdk:0.8.6`.**

If it doesn't resolve:
- Confirm `mavenCentral()` is in repositories (Step 2a).
- Confirm the version `0.8.6` is correct.
- Check network connectivity.

**Do not proceed to Step 3 until this step passes.**

## Step 3: Add permissions to AndroidManifest.xml

Read the app module's `AndroidManifest.xml` (identified in Step 1d). Check which permissions already exist:

```bash
grep -n "uses-permission" --include="AndroidManifest.xml" -r . | grep -v "/build/"
```

If `INTERNET` is missing, add it. `USE_BIOMETRIC` is optional (the SDK merges it automatically):

```xml
<uses-permission android:name="android.permission.INTERNET" />
```

Add **inside** the `<manifest>` tag, **before** the `<application>` tag. Do not duplicate existing permissions.

## Step 4 (recommended): Add SDK warmup to the Application class

### If a custom Application class exists (found in Step 1c)

1. Read the file. Add the SDK imports alongside existing imports:
   ```kotlin
   import `in`.dezerv.portfolio_tracker_sdk.DezervSDK
   import `in`.dezerv.portfolio_tracker_sdk.core.DezervSDKEnvironment
   import `in`.dezerv.portfolio_tracker_sdk.core.DezervSDKInitConfig
   import `in`.dezerv.portfolio_tracker_sdk.core.DezervSDKTheme
   import `in`.dezerv.portfolio_tracker_sdk.core.DezervViewType
   ```

2. Inside the existing `onCreate()`, **append** after `super.onCreate()` and any existing code:
   ```kotlin
   if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
       DezervSDK.initialize(
           context = this,
           dezervSDKInitConfig = DezervSDKInitConfig(
               theme = DezervSDKTheme.light,
               viewType = DezervViewType.FULL_VIEW,
               isDebug = BuildConfig.DEBUG,
               environment = DezervSDKEnvironment.PRODUCTION
           )
       )
   }
   ```
   Do **not** replace the `onCreate()` body — preserve existing code.

### If no custom Application class exists

1. Create a new file in the same package as the main Activity:
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
                       environment = DezervSDKEnvironment.PRODUCTION
                   )
               )
           }
       }
   }
   ```
   Use the partner's naming convention. Check existing classes for the package name.

2. Register in `AndroidManifest.xml` — add `android:name` to the `<application>` tag:
   ```xml
   <application
       android:name=".MyApplication"
       ... existing attributes ... >
   ```
   If `android:name` already points to another class, modify that class instead.

## Step 5: Add DezervSDKView to a layout

### If modifying an existing Activity's layout

Read the layout XML that the hosting Activity inflates (find it via `setContentView` or `R.layout.`). **Add** the SDK view inside the existing layout hierarchy where the user wants it:

```xml
<in.dezerv.portfolio_tracker_sdk.DezervSDKView
    android:id="@+id/dezervSDKView"
    android:layout_width="match_parent"
    android:layout_height="match_parent" />
```

### If creating a new Activity

Create a new layout file (e.g. `activity_portfolio.xml`) with the SDK view as the root or inside a container.

## Step 6: Build config, bind view, show

Read the hosting Activity file. Then modify it to add the SDK setup. Read `references/activity-template.kt` for the full reference implementation with event handling.

Key requirements:

1. Add SDK imports alongside existing imports.
2. Add a `private var dezervSDKInstance: DezervSDK? = null` property.
3. Inside `onCreate()`, **after** `setContentView(...)` and any existing setup code, append the SDK configuration:
   - Gate with `Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU`.
   - Find the view: `findViewById<DezervSDKView>(R.id.dezervSDKView)`.
   - Build config with `DezervSDKConfig(partnerAuthToken, partnerUserMeta, theme, viewType, isDebug)`.
   - Build and show: `DezervSDK.Builder(this).setConfig(config).withView(view).withMessageListener { ... }.build()` then `.show()`.
4. In `onDestroy()`, null out the instance.
5. `partnerAuthToken` must come from the partner backend — use `"PARTNER_AUTH_TOKEN"` as placeholder.
6. Read `references/user-meta-fields.md` for required `partnerUserMeta` fields.

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
