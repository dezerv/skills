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

## Step 1: Add the Swift package

Package URL: `https://github.com/dezerv/portfolio-sdk-ios`  
Current from-version: **0.8.4**

### Xcode (recommended)

1. **File > Add Package Dependencies...**
2. Paste `https://github.com/dezerv/portfolio-sdk-ios`
3. Choose **Up to Next Major Version** (or from `0.8.4`)
4. Add product **PortfolioTrackerSDK** to the app target

### Package.swift

```swift
dependencies: [
    .package(url: "https://github.com/dezerv/portfolio-sdk-ios", from: "0.8.4")
]
```

```swift
.target(
    name: "YourApp",
    dependencies: [
        .product(name: "PortfolioTrackerSDK", package: "portfolio-sdk-ios")
    ]
)
```

Import where needed:

```swift
import PortfolioTrackerSDK
```

## Step 2: Info.plist — Face ID

```xml
<key>NSFaceIDUsageDescription</key>
<string>This app requires Face ID permission to authenticate you securely.</string>
```

Do **not** add local-network / Bonjour keys unless the partner has a separate requirement — they are not part of the Dezerv install docs.

## Step 2b: Locate integration points

Before writing any code, discover the partner's project structure so the SDK init lands in the right place.

### Find the app entry point

```bash
grep -r "@main" --include="*.swift" .
```

This locates the `@main` App struct (SwiftUI) or `@main` AppDelegate. The warmup (`DezervSDK.shared.initialize`) **must** go in this file's `init()` (SwiftUI) or `application(_:didFinishLaunchingWithOptions:)` (UIKit).

If no `@main` is found, check for `@UIApplicationMain`:

```bash
grep -r "@UIApplicationMain" --include="*.swift" .
```

### Check for existing SDK integration

```bash
grep -r "import PortfolioTrackerSDK" --include="*.swift" .
grep -r "DezervSDK" --include="*.swift" .
```

If results are found, the SDK may already be integrated. Review the existing integration before adding duplicate code. Ask the user whether they want to update or replace the existing setup.

### Identify the presentation target

```bash
grep -rn "DezervSDKView" --include="*.swift" .
```

If the partner already has a view hosting the SDK, modify that rather than creating a new one. If not, ask where they want the SDK presented (new screen, sheet, tab, etc.).

### Confirm the Xcode target

Check which target the entry-point file belongs to — look for it in `*.pbxproj` or `Package.swift`:

```bash
grep -l "PortfolioTrackerSDK" . -r --include="*.pbxproj" --include="Package.swift"
```

Ensure the SDK product is linked to the **same target** as the app entry point.

## Step 3 (recommended): Warmup at app start

The SDK is a singleton: `DezervSDK.shared`. Warmup is async and non-blocking. Pass `environment` so pre-load uses the correct URL (defaults to production if omitted).

```swift
import SwiftUI
import PortfolioTrackerSDK

@main
struct MyApp: App {
    init() {
        DezervSDK.shared.initialize(environment: .production) // or .preprod
        // Optional completion:
        // DezervSDK.shared.initialize(environment: .production) { result in
        //     switch result {
        //     case .success: print("Warmup ok")
        //     case .failure(let error): print("Warmup failed: \(error.message)")
        //     }
        // }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

Note: `.integration` is Dezerv-internal only — not for partner apps.

## Step 4: Configure Builder, then present `DezervSDKView`

```swift
import SwiftUI
import PortfolioTrackerSDK

struct SDKContainerView: View {
    @State private var isLoading = false
    @State private var showSDK = false
    @State private var errorMessage: String?

    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Configuring SDK...")
            } else if let errorMessage {
                Text(errorMessage).foregroundColor(.red)
            } else if showSDK {
                DezervSDKView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if !showSDK && !isLoading {
                Button("Open Portfolio") {
                    configureAndShowSDK()
                }
            }
        }
    }

    private func configureAndShowSDK() {
        isLoading = true
        errorMessage = nil

        // Replace with token from partner backend
        let authToken = "PARTNER_AUTH_TOKEN"

        let userMeta: [String: Any] = [
            // Session / analytics (required)
            "session_id": "REPLACE_SESSION_ID",
            "schema_version": "2.0",
            "partner": "REPLACE_PARTNER_ID", // e.g. moneycontrol

            // Personalization (required)
            "partner_category": "stock", // stock|mutual_fund|index|commodity|ipo|news|homepage|comms|portfolio
            "partner_symbol": "RELIANCE", // "" when category is homepage or news
            "partner_page_title": "Reliance Industries Share Price",
            "partner_image_text": "Track your portfolio in one place",
            // "partner_keywords": ["tag1"], // required when partner_category == news

            // Recommended attribution
            "partner_source": "home_tab",
            "partner_page_url": "https://partner.com/stocks/reliance-industries",
            "partner_campaign": "example_campaign",

            // Optional
            // "phone": "9876543201",
            // "pan": "ABCDE1234F",
            // "deeplink": "/abc",
            // "sdkMetrics": ["startTime": 0.0, "endTime": 0.0],
            // "partner_section_name": "Top Gainers",
            // "partner_cta_copy": "Stop Guessing, Get wealth review by an Expert",
            // "partner_cta_position": "hero", // hero|inline|sticky
            // "partner_medium": "app", // app|whatsapp
        ]

        let config = DezervSDKConfigParms(
            partnerAuthToken: authToken,
            partnerUserMeta: userMeta,
            theme: .light,      // or .dark
            viewType: .fullView // or .tabView for embedded / tab UI
        )

        let result = DezervSDK.Builder()
            .setConfig(config)
            .withMessageListener { event, payload in
                handleSDKEvent(event, payload: payload)
            }
            .build()

        DispatchQueue.main.async {
            isLoading = false
            switch result {
            case .success:
                showSDK = true
            case .failure(let error):
                // error.code — error code string (e.g. "sdk_error")
                // error.message — human-readable description
                // error.underlyingError — optional underlying system error
                errorMessage = "SDK setup failed: \(error.message)"
            }
        }
    }

    private func handleSDKEvent(_ event: DezervSDKEvent, payload: [String: Any]?) {
        switch event {
        case .sdkInitializationSuccess:
            print("SDK initialized")
        case .sdkInitializationError:
            print("SDK init error: \(payload?["error"] ?? "unknown")")
        case .exit:
            if let errorCode = payload?["errorCode"] as? String,
               errorCode == "sdk_error" {
                // Re-initialize SDK with new auth token
                print("exit due to sdk_error — re-init needed")
            } else {
                DispatchQueue.main.async {
                    showSDK = false
                    DezervSDK.shared.dispose()
                }
            }
        case .userAuth:
            print("userAuth: \(payload ?? [:])")
        case .setUserId:
            print("userId: \(payload?["userId"] ?? "")")
        case .logout:
            DispatchQueue.main.async {
                DezervSDK.shared.logout()
                DezervSDK.shared.dispose()
            }
        case .onDeeplink:
            print("deeplink: \(payload?["link"] ?? "")")
        case .analytics:
            print("analytics: \(payload ?? [:])")
        case .themeChange:
            print("theme: \(payload?["theme"] ?? "")")
        default:
            print("event=\(event) payload=\(payload ?? [:])")
        }
    }
}
```

`DezervSDKView` also accepts an optional `theme` parameter:

```swift
DezervSDKView(theme: .dark)
```

Sheet presentation alternative:

```swift
.sheet(isPresented: $showSDK) {
    DezervSDKView()
}
```

### Observing errors reactively

`DezervSDK.shared.error` is a `@Published` property. In SwiftUI you can observe it:

```swift
@StateObject private var sdk = DezervSDK.shared
// sdk.error will update reactively
```

### Logout / dispose

```swift
DezervSDK.shared.logout()
DezervSDK.shared.dispose()
```

Call `dispose()` when the SDK UI is dismissed; call `logout()` when the partner user signs out of the host app.

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
