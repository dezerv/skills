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

Observe where the partner keeps their view files (e.g. `Views/`, `Screens/`, `Features/`, or flat alongside the app). Create the SDK container view following the same convention. Do **not** ask the user where to present the SDK — the skill creates a standalone container view; how the partner surfaces it (tab, sheet, push) is their decision.

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

## Step 5: Create the SDK presentation view

Create a new SwiftUI View file that handles Builder configuration and presents `DezervSDKView`. Place it following the project's file conventions (found in Step 1e). Read `references/sdk-view-template.swift` for the full reference implementation with event handling.

Key requirements for the view:

1. `import PortfolioTrackerSDK` at the top.
2. Build the SDK with `DezervSDK.Builder()` → `.setConfig(config)` → `.withMessageListener { ... }` → `.build()`.
3. Config uses `DezervSDKConfigParms(partnerAuthToken:partnerUserMeta:theme:viewType:)`.
4. On `.success`, present `DezervSDKView()`. On `.failure`, show the error.
5. Handle the `.exit` event — call `DezervSDK.shared.dispose()` on dismissal.
6. Handle the `.logout` event — call `DezervSDK.shared.logout()` then `dispose()`.
7. `partnerAuthToken` must come from the partner backend, not hardcoded. Use `"PARTNER_AUTH_TOKEN"` as placeholder.
8. Read `references/user-meta-fields.md` for required `partnerUserMeta` fields.

`DezervSDKView` also accepts a `theme` parameter: `DezervSDKView(theme: .dark)`.

The container view is self-contained — the partner wires it into their navigation (tab, sheet, push, etc.) themselves.

### Observing errors reactively

`DezervSDK.shared.error` is a `@Published` property:

```swift
@StateObject private var sdk = DezervSDK.shared
```

### Logout / dispose

Call `dispose()` when the SDK UI is dismissed. Call `logout()` when the partner user signs out of the host app:

```swift
DezervSDK.shared.logout()
DezervSDK.shared.dispose()
```

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

3. **Builder + DezervSDKView are in a presentation context** — not in the `@main` App struct:
   ```bash
   grep -rn "DezervSDK.Builder" --include="*.swift" .
   grep -rn "DezervSDKView()" --include="*.swift" .
   ```
   Both should be in a View or ViewController, not in the app entry point.

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
- The agent may put `DezervSDK.Builder` in the `@main` App struct alongside warmup. Builder + view presentation belong in a separate View or ViewController, not in the app entry point.
- `DezervSDK.shared` is a singleton — calling `initialize` more than once is a bug. If the agent adds warmup to both `AppDelegate` and a SwiftUI `@main` struct, one must be removed.
- Never hardcode real `partnerAuthToken` JWTs or PII (`phone`, `pan`) in source. Use placeholder values in code; fetch real tokens from the partner backend at runtime.

## Run validation

After completing all steps, run the automated validator from the project root:

```bash
bash scripts/validate-integration.sh
```

Fix any failures before considering the integration complete.
