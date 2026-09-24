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

## Verification

1. SPM resolves `portfolio-sdk-ios`; `import PortfolioTrackerSDK` compiles
2. App builds for iOS 15+
3. With a real `partnerAuthToken`, `Builder` returns `.success` and `DezervSDKView` shows content
4. Console shows init success (or a clear init error)
5. Exit dismisses the view and `dispose()` runs

## Troubleshooting

| Symptom | Check |
|---------|--------|
| Package not found | URL `https://github.com/dezerv/portfolio-sdk-ios`; network; remove/re-add package |
| Deployment target errors | Set iOS **15.0+**, Xcode **15+** |
| Face ID issues | `NSFaceIDUsageDescription` present; test on device |
| Auth / blank SDK | Invalid or missing `partnerAuthToken` |
| Personalization wrong | Required meta fields missing or wrong `partner_category` |
| Warmup ineffective | Pass `environment: .production` or `.preprod` |

## Do not

- Do not invent a `PortfolioTrackerSDK(Configuration(apiUsername:…))` init API — use `DezervSDK.shared` / `DezervSDK.Builder` + `DezervSDKConfigParms`
- Do not hardcode production tokens or PII in source control
- Do not treat SPM install alone as done — you must `setConfig` + `build` + present `DezervSDKView`
