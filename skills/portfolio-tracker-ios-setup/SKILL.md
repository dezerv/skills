---
name: portfolio-tracker-ios-setup
description: >
  Set up Portfolio Tracker (Dezerv) SDK in an iOS project — Swift Package
  Manager, Face ID Info.plist, partner auth token, user metadata,
  DezervSDK.Builder, DezervSDKView, optional warmup, events, logout/dispose.
  Use when the user asks to integrate, set up, or configure the Portfolio
  Tracker / Dezerv SDK for iOS, or mentions "portfolio tracker ios",
  "dezerv ios sdk", "portfolio sdk swift", or "portfolio sdk xcode".
---

# Portfolio Tracker SDK — iOS Setup

Integrate the Dezerv Portfolio Tracker SDK into the **partner app** (not the Skills or docs repos). Follow steps in order. After each step, verify before continuing.

**Identifying an iOS project:** If the project root has a `Package.swift`, `*.xcodeproj`, or `*.xcworkspace`, it is an iOS/macOS project — even if it contains Rust, C, or other native dependencies as local packages. Do not ask the user to confirm the platform; proceed with the iOS setup.

Canonical docs (prefer these if anything conflicts):
- https://dezerv.github.io/portfolio-tracker-sdk-docs/current/ios/installation
- https://dezerv.github.io/portfolio-tracker-sdk-docs/current/ios/usage
- https://dezerv.github.io/portfolio-tracker-sdk-docs/current/ios/events

## Prerequisites

Confirm the host app has:
- **Xcode 15.0+**
- **iOS deployment target 15.0+**
- Swift 5.0+
- Apple Developer account for device / Face ID testing
- A **backend-issued `partnerAuthToken`**. Do not invent credentials; ask the partner for their Dezerv token endpoint / sample token.

## Before you start — credentials

The SDK does **not** use username/password or `.xcconfig` API keys for init. You need:

1. `partnerAuthToken` — token from the partner backend (Dezerv auth flow)
2. `partnerUserMeta` — dictionary with required personalization + session fields (below)

If the user has no token yet, stop after SPM + Info.plist and tell them to obtain a partner auth token from Dezerv before calling `Builder` / presenting `DezervSDKView`.

## Step 1: Discover the project structure

Before modifying anything, map the project so every change lands in the right file.

### 1a. Check for existing SDK integration

```bash
grep -r "import PortfolioTrackerSDK" --include="*.swift" .
grep -r "DezervSDK" --include="*.swift" .
```

If results are found, the SDK is already integrated. Review what exists and ask the user whether to update or replace it. Do **not** add duplicate init/builder code.

### 1b. Identify how the project manages dependencies

```bash
# SPM-based project?
find . -name "Package.swift" -not -path "*/build/*" -not -path "*/.build/*"

# Xcode project with SPM packages?
find . -name "*.pbxproj" -not -path "*/build/*"
```

- If `Package.swift` exists at the project root → SPM project. Modify that file.
- If only `.pbxproj` exists → Xcode-managed project. Tell the user to add the package via **File > Add Package Dependencies** in Xcode (the agent cannot modify `.pbxproj` reliably).

### 1c. Find the app entry point

```bash
grep -rn "@main" --include="*.swift" .
```

Read the matched file. Note:
- **SwiftUI app**: warmup goes in the existing `init()` of the `@main` struct. If no `init()` exists, add one.
- **UIKit app**: warmup goes in `application(_:didFinishLaunchingWithOptions:)` in the `AppDelegate`.

If no `@main` is found, try `@UIApplicationMain`:
```bash
grep -rn "@UIApplicationMain" --include="*.swift" .
```

### 1d. Find all Info.plist files

```bash
find . -name "Info.plist" -not -path "*/build/*" -not -path "*/.build/*"
```

There may be several (app, tests, extensions). The Face ID key goes in the **app target's** Info.plist — the one that lives alongside the app source, not test or extension plists.

### 1e. Note the project's file/folder conventions

```bash
ls -d */ || ls
find . -name "*.swift" -not -path "*/build/*" -not -path "*/.build/*" -maxdepth 3 | head -20
```

Observe where the partner keeps their view files (e.g. `Views/`, `Screens/`, `Features/`, or flat alongside the app). Create the thin SDK host view (+ configurator) following the same convention. Do **not** ask the user where to present the SDK yet — that is Step 5b; the skill creates a standalone host with no launcher button.

## Step 2: Add the Swift package dependency

Package URL: `https://github.com/dezerv/portfolio-sdk-ios`
Current from-version: **0.8.4**

### If `Package.swift` exists

Read the existing `Package.swift`. Then:

1. **Append** to the existing `dependencies` array (do not replace it):
   ```swift
   .package(url: "https://github.com/dezerv/portfolio-sdk-ios", from: "0.8.4")
   ```

2. Find the **app's executable or library target** (not the test target). **Append** to its `dependencies` array:
   ```swift
   .product(name: "PortfolioTrackerSDK", package: "portfolio-sdk-ios")
   ```

3. Verify the target name matches the app — don't add the SDK to test targets or helper packages.

### If Xcode-managed (no `Package.swift`)

Tell the user:
> In Xcode: **File > Add Package Dependencies...** → paste `https://github.com/dezerv/portfolio-sdk-ios` → choose **Up to Next Major Version** from `0.8.4` → add **PortfolioTrackerSDK** to the app target. Xcode will resolve and download the package automatically.

Do not attempt to edit `.pbxproj` files directly.

## Step 2b: Resolve and download the package — MANDATORY

**Do not skip this step.** The dependency does not exist locally until it is resolved.

```bash
swift package resolve
```

This downloads the SDK source. Wait for it to finish — it may take 30-60 seconds.

**Verify the package downloaded successfully:**

```bash
grep -r "portfolio-sdk-ios" Package.resolved
```

If `Package.resolved` shows the entry, the SDK is downloaded. If `swift package resolve` fails:
- Check the package URL is exactly `https://github.com/dezerv/portfolio-sdk-ios`.
- Check network connectivity.
- If `Package.resolved` has a conflicting entry, delete it and re-resolve.

**Do not proceed to Step 3 until this step passes.**

## Step 3: Add Face ID to Info.plist

Read the app target's `Info.plist` (identified in Step 1d). Check if `NSFaceIDUsageDescription` already exists:

```bash
grep -r "NSFaceIDUsageDescription" --include="*.plist" .
```

If missing, add this key-value pair inside the top-level `<dict>`:

```xml
<key>NSFaceIDUsageDescription</key>
<string>This app requires Face ID permission to authenticate you securely.</string>
```

Do **not** add local-network / Bonjour keys unless the partner has a separate requirement.

## Step 4 (recommended): Add SDK warmup to the app entry point

Read the entry-point file found in Step 1c. Add the warmup call to the **existing** `init()` — do not replace the struct or remove existing code.

### SwiftUI (`@main` struct)

1. Add `import PortfolioTrackerSDK` alongside the existing imports.
2. Inside the existing `init()`, append this line (after any existing init code):
   ```swift
   DezervSDK.shared.initialize(environment: .production) // or .preprod
   ```
3. If no `init()` exists, create one — but preserve all existing properties and the `body`:
   ```swift
   init() {
       // ... keep any existing init code above ...
       DezervSDK.shared.initialize(environment: .production)
   }
   ```

### UIKit (`AppDelegate`)

1. Add `import PortfolioTrackerSDK` alongside the existing imports.
2. Inside the existing `application(_:didFinishLaunchingWithOptions:)`, append:
   ```swift
   DezervSDK.shared.initialize(environment: .production)
   ```
   before `return true`. Do not replace the method body.

**Do not** add warmup in both places. Pick whichever the project uses. `.integration` environment is Dezerv-internal only.

**Preprod setup:** If the user needs preprod, pass `.preprod` in `initialize()` AND use a preprod-issued `partnerAuthToken` in `DezervSDKConfigParms`. They must match — a production token with a preprod warmup (or vice versa) will fail.

## Step 5: Create the SDK presentation layer

Create **two** pieces following the project's file conventions (found in Step 1e). Read `references/sdk-view-template.swift` for the full reference.

1. **`DezervSDKConfigurator`** — SDK wiring only (no SwiftUI). Builds `DezervSDKConfigParms`, calls `DezervSDK.Builder`, and owns the message/event listener.
2. **`DezervPortfolioHostView`** — thin UI host only. Calls the configurator in `.task`, then presents `DezervSDKView()` on success (or an error message on failure).

**Do not** put an "Open Portfolio" button inside the host view. How the partner surfaces the host (sheet / cover / push / tab) is Step 5b.

**IMPORTANT — the generated code must include:**
- All inline comments from the template explaining what each field/event does.
- All optional `partnerUserMeta` fields as commented-out lines (phone, pan, deeplink, sdkMetrics, partner_section_name, partner_cta_copy, partner_cta_position, partner_medium, partner_keywords). Partners need to see what's available.
- `// TODO:` markers on every line the partner must customize (auth token, session ID, partner ID, analytics forwarding, deeplink handling). These appear in Xcode's task navigator.
- Wrap SDK types in `#if canImport(PortfolioTrackerSDK)` / `#endif` — prevents build errors if the package hasn't resolved yet.

Do not strip comments, optional fields, or TODOs to "clean up" the code.

Key requirements:

1. `import PortfolioTrackerSDK` at the top of both files (or the single file if the partner keeps them together).
2. Configurator builds with `DezervSDK.Builder()` → `.setConfig(config)` → `.withMessageListener { ... }` → `.build()`.
3. Config uses `DezervSDKConfigParms(partnerAuthToken:partnerUserMeta:theme:viewType:)`.
4. Host presents `DezervSDKView()` only after configurator returns success; show the failure message otherwise.
5. Handle `.exit` in the configurator — `dispose()` then invoke the host's dismiss callback.
6. Handle `.logout` — `logout()` then `dispose()`, then invoke the host logout callback.
7. `partnerAuthToken` must come from the partner backend, not hardcoded. Use `"PARTNER_AUTH_TOKEN"` as placeholder.
8. Read `references/user-meta-fields.md` for required `partnerUserMeta` fields.
9. Choose `viewType`: `.fullView` for sheet / push / cover; `.tabView` when embedding in a `TabView`.

`DezervSDKView` also accepts a `theme` parameter: `DezervSDKView(theme: .dark)`.

## Step 5b: Wire up the SDK launch

After creating the host view, ask the user:

> "How would you like to open the Portfolio Tracker — as a **sheet**, **full-screen cover**, **navigation push**, or **tab**?"

Then wire it into the partner's existing view based on their answer:

- **Sheet**: Add `@State private var showPortfolio = false` and `.sheet(isPresented: $showPortfolio) { DezervPortfolioHostView() }` to the parent view they specify.
- **Full-screen cover**: Same state, use `.fullScreenCover(isPresented:)` instead.
- **NavigationLink**: Add `NavigationLink("Portfolio") { DezervPortfolioHostView() }` inside the partner's existing NavigationStack/NavigationView.
- **Tab**: Add `DezervPortfolioHostView().tabItem { Label("Portfolio", systemImage: "chart.line.uptrend.xyaxis") }` inside the partner's existing TabView — and set configurator `viewType: .tabView`.

Ask the user which **existing view or screen** should have the launch point, then modify that file directly.

### Observing errors reactively

`DezervSDK.shared.error` is a `@Published` property:

```swift
@StateObject private var sdk = DezervSDK.shared
```

## Step 6: Add logout handling

The partner's app must call `DezervSDK.shared.logout()` when the user logs out of the host app. Find the partner's existing logout flow and add the SDK cleanup:

```bash
grep -rn "logout\|signOut\|sign_out\|logOut" --include="*.swift" . | grep -v "/build/" | grep -v "DezervSDK"
```

In the partner's logout function, add:

```swift
// Clear Dezerv SDK session data and cookies
DezervSDK.shared.logout()
// Release SDK resources
DezervSDK.shared.dispose()
```

**`dispose()` vs `logout()`:**
- `dispose()` — call when the SDK **view** is dismissed (frees resources, SDK can be re-shown later)
- `logout()` — call when the **user** logs out of the host app (clears session data and cookies)
- On user logout, call **both** in order: `logout()` then `dispose()`

## Required `partnerUserMeta` fields

Read `references/user-meta-fields.md` for the full field table when constructing or debugging `partnerUserMeta`.

## Verification

### Build & runtime checks

1. SPM resolves `portfolio-sdk-ios`; `import PortfolioTrackerSDK` compiles
2. App builds for iOS 15+
3. With a real `partnerAuthToken`, `Builder` returns `.success` and `DezervSDKView` shows content
4. Console shows init success (or a clear init error)
5. Exit dismisses the view and `dispose()` runs

### Placement validation (run after all steps)

After writing code, verify correct placement:

1. **Warmup is in the entry point only** — confirm `DezervSDK.shared.initialize` appears exactly once, inside the `@main` struct/class:
   ```bash
   grep -rn "DezervSDK.shared.initialize" --include="*.swift" .
   ```
   Expected: one match, in the file identified in Step 2b. If found elsewhere, remove the duplicate.

2. **No duplicate imports** — `import PortfolioTrackerSDK` should appear only in files that use the SDK:
   ```bash
   grep -rn "import PortfolioTrackerSDK" --include="*.swift" .
   ```

3. **Configurator + DezervSDKView are in a presentation context** — not in the `@main` App struct:
   ```bash
   grep -rn "DezervSDKConfigurator\|DezervSDK.Builder" --include="*.swift" .
   grep -rn "DezervSDKView()" --include="*.swift" .
   ```
   Builder belongs in the configurator; `DezervSDKView` belongs in the thin host. Neither belongs in the app entry point.

4. **dispose() is called on dismissal** — confirm cleanup exists:
   ```bash
   grep -rn "\.dispose()" --include="*.swift" .
   ```

5. **No hardcoded tokens** — confirm placeholder strings are present, not real JWTs:
   ```bash
   grep -rn "partnerAuthToken" --include="*.swift" .
   ```
   The value should be `"PARTNER_AUTH_TOKEN"` or fetched from a backend call, never a real token literal.

## Troubleshooting

Read `references/troubleshooting.md` if the build fails, the SDK shows a blank screen, or runtime errors appear.

## Gotchas

- The agent may try to create a `PortfolioTrackerSDK(Configuration(apiUsername:…))` or similar username/password init — **this API does not exist**. The only init path is `DezervSDK.shared` (singleton) + `DezervSDK.Builder()` + `DezervSDKConfigParms`. If the agent invents a different API shape, it's hallucinating.
- The agent may consider SPM install as "done" — it's not. The SDK does nothing until `setConfig` + `build` returns `.success` and `DezervSDKView` is presented. Adding the package dependency is step 1 of 4.
- `.integration` environment exists in the SDK enum but is **Dezerv-internal only**. Never suggest it for partner apps — only `.production` or `.preprod`.
- The agent may put `DezervSDK.Builder` in the `@main` App struct alongside warmup. Builder belongs in `DezervSDKConfigurator`; view presentation belongs in `DezervPortfolioHostView` — not in the app entry point.
- The agent may put an "Open Portfolio" button inside the host view. Do **not** — launch wiring is Step 5b in the parent view.
- `DezervSDK.shared` is a singleton — calling `initialize` more than once is a bug. If the agent adds warmup to both `AppDelegate` and a SwiftUI `@main` struct, one must be removed.
- Never hardcode real `partnerAuthToken` JWTs or PII (`phone`, `pan`) in source. Use placeholder values in code; fetch real tokens from the partner backend at runtime.
- The environment in `DezervSDK.shared.initialize()` and the `partnerAuthToken` in `DezervSDKConfigParms` must target the same environment (both production or both preprod). Mismatched environments cause auth failures or blank screens.

## Run validation

After completing all steps, run the automated validator from the project root:

```bash
bash scripts/validate-integration.sh
```

Fix any failures before considering the integration complete.
