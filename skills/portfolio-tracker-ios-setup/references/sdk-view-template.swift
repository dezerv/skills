// =============================================================================
// Reference implementation for the Dezerv Portfolio Tracker SDK — iOS
// Adapt to the partner's existing project — do not copy verbatim.
//
// Architecture (UI and SDK wiring are separated):
//   - DezervSDK.shared.initialize() → @main App struct init() ONLY (one-time warmup)
//   - DezervSDKConfigurator         → config, Builder, event handling (no UI)
//   - DezervPortfolioHostView       → thin SwiftUI host that presents DezervSDKView
//   - DezervSDK.shared.logout()     → When the partner user logs out of the host app
//   - DezervSDK.shared.dispose()    → When the SDK UI is dismissed
//
// The SDK is a SINGLETON (DezervSDK.shared). initialize() must be called
// exactly ONCE at app start. Builder + DezervSDKView is used each time
// the SDK UI needs to be presented.
//
// How partners present this host (sheet / fullScreenCover / NavigationLink / tab)
// is decided in SKILL Step 5b — this file does NOT include a launcher button.
// =============================================================================


// =============================================================================
// WARMUP — goes in the @main App struct init(), NOT in a View
// Add to: the existing init() of the partner's @main struct
// =============================================================================
//
// import PortfolioTrackerSDK
//
// @main
// struct MyApp: App {
//     init() {
//         // ... existing init code ...
//
//         // One-time async warmup — non-blocking, safe at startup.
//         // Environment: .production or .preprod (.integration is Dezerv-internal only)
//         // ⚠️ If using .preprod, also use a preprod auth token in DezervSDKConfigParms
//         //    — the environment in initialize() and the token must match
//         DezervSDK.shared.initialize(environment: .production)
//
//         // Optional: with completion handler for logging/metrics
//         // DezervSDK.shared.initialize(environment: .production) { result in
//         //     DispatchQueue.main.async {
//         //         switch result {
//         //         case .success: print("Warmup successful")
//         //         case .failure(let error): print("Warmup failed: \(error.message)")
//         //         }
//         //     }
//         // }
//     }
// }


#if canImport(PortfolioTrackerSDK)
import SwiftUI
import PortfolioTrackerSDK

// =============================================================================
// FILE 1: DezervSDKConfigurator — SDK wiring only (no SwiftUI)
// Place in: same module as the host view (e.g. Services/ or Features/Portfolio/)
// =============================================================================

/// Builds SDK config, attaches the message listener, and owns event handling.
/// Keep this free of View types so UI and integration logic stay separate.
enum DezervSDKConfigurator {

    /// Result of attaching the SDK for presentation.
    enum AttachResult {
        case success
        case failure(message: String)
    }

    /// Callbacks the thin host (or navigation layer) must implement.
    struct HostCallbacks {
        /// Called on normal `.exit` — dismiss the host (sheet/push/tab).
        var onDismiss: () -> Void
        /// Called when `.exit` includes `errorCode == "sdk_error"` — refresh token and re-attach.
        var onReinitialize: () -> Void
        /// Called on `.logout` after SDK session is cleared — also clear the host app session.
        var onHostLogout: () -> Void
    }

    // -------------------------------------------------------------------------
    // Public entry — call from the host view's `.task` / `onAppear`
    // -------------------------------------------------------------------------

    /// Configures `DezervSDK.Builder` and registers the event listener.
    /// On success the host should present `DezervSDKView()`.
    @discardableResult
    static func attach(callbacks: HostCallbacks) -> AttachResult {
        let authToken = "PARTNER_AUTH_TOKEN" // TODO: Replace with your backend's /auth/token response

        let config = DezervSDKConfigParms(
            partnerAuthToken: authToken,
            partnerUserMeta: buildUserMeta(),

            // Theme — .light or .dark
            theme: .light,

            // View type:
            //   .fullView = full-screen standalone SDK view (default for sheet / push / cover)
            //   .tabView  = embedded/nested view for tab-based navigation
            // Match this to how the partner presents DezervPortfolioHostView.
            viewType: .fullView

            // ⚠️ PREPROD SETUP: If targeting preprod, you must change BOTH:
            //   1. DezervSDK.shared.initialize() in @main: environment: .preprod
            //   2. This config: use a preprod-issued partnerAuthToken
            //   Mismatched environments will cause auth failures or blank screens
        )

        let result = DezervSDK.Builder()
            .setConfig(config)
            .withMessageListener { event, payload in
                handleSDKEvent(event, payload: payload, callbacks: callbacks)
            }
            .build()

        switch result {
        case .success:
            return .success
        case .failure(let error):
            // error.code — error code string (e.g. "sdk_error")
            // error.message — human-readable description
            // error.underlyingError — optional underlying system error
            return .failure(message: error.message)
        }
    }

    // -------------------------------------------------------------------------
    // User metadata — personalization + session + attribution
    // See references/user-meta-fields.md for the full field table
    // -------------------------------------------------------------------------

    static func buildUserMeta() -> [String: Any] {
        [
            // --- Session / analytics (required) ---
            "session_id": "REPLACE_SESSION_ID",             // TODO: Replace with unique session ID
            "schema_version": "2.0",                         // Always send "2.0"
            "partner": "REPLACE_PARTNER_ID",                 // TODO: Replace with your partner ID (e.g. "moneycontrol")

            // --- Personalization (required) ---
            // partner_category: stock | mutual_fund | index | commodity | ipo | news | homepage | comms | portfolio
            "partner_category": "stock",
            "partner_symbol": "RELIANCE",                    // Empty string "" when category is homepage or news
            "partner_page_title": "Reliance Industries Share Price",
            "partner_image_text": "Track your portfolio in one place",
            // "partner_keywords": ["tag1"],                 // Required when partner_category == "news"

            // --- Recommended attribution ---
            "partner_source": "home_tab",                    // Internal navigation source
            "partner_page_url": "https://partner.com/stocks/reliance-industries",
            "partner_campaign": "example_campaign",          // Campaign identifier

            // --- Optional fields ---
            // "phone": "9876543201",                        // User's phone number
            // "pan": "ABCDE1234F",                          // User's PAN
            // "deeplink": "/abc",                           // In-SDK route to navigate to
            // "sdkMetrics": [                               // Timestamps of the /auth/token API call
            //     "startTime": 0.0,
            //     "endTime": 0.0
            // ],
            // "partner_section_name": "Top Gainers",        // Section name on the partner page
            // "partner_cta_copy": "Stop Guessing, Get wealth review by an Expert",
            // "partner_cta_position": "hero",               // hero | inline | sticky
            // "partner_medium": "app",                      // app | whatsapp
        ]
    }

    // -------------------------------------------------------------------------
    // Event handler — partner-facing events from docs/ios/events.md
    // Remaining cases fall through to default (internal/diagnostic events)
    // -------------------------------------------------------------------------

    private static func handleSDKEvent(
        _ event: DezervSDKEvent,
        payload: [String: Any]?,
        callbacks: HostCallbacks
    ) {
        switch event {

        case .sdkInitializationSuccess:
            // SDK WebView is loaded and ready — safe to interact
            print("DezervSDK: initialized successfully")

        case .sdkInitializationError:
            // Config or auth issue — check partnerAuthToken and userMeta
            let error = payload?["error"] as? String ?? "unknown"
            print("DezervSDK: init failed — \(error)")

        case .exit:
            // ACTION REQUIRED: dismiss the SDK host
            if let errorCode = payload?["errorCode"] as? String,
               errorCode == "sdk_error" {
                // SDK-side error — fetch a fresh auth token and re-configure
                print("DezervSDK: exit with sdk_error — re-init with new token")
                DispatchQueue.main.async {
                    callbacks.onReinitialize()
                }
            } else {
                // Normal exit — release SDK resources, then dismiss host UI
                DispatchQueue.main.async {
                    DezervSDK.shared.dispose()
                    callbacks.onDismiss()
                }
            }

        case .logout:
            // ACTION REQUIRED: user logged out inside the SDK
            DispatchQueue.main.async {
                DezervSDK.shared.logout()   // Clears SDK session data
                DezervSDK.shared.dispose()  // Releases SDK resources
                callbacks.onHostLogout()    // TODO: Also clear your app's own auth session
            }

        case .userAuth:
            // User authenticated — payload has phone, flow, clientId, deviceId
            let phone = payload?["phone"] as? String ?? ""
            let flow = payload?["flow"] as? String ?? ""    // "signup" or "login"
            print("DezervSDK: userAuth flow=\(flow) phone=\(phone)")

        case .onDeeplink:
            // User tapped a deeplink inside the SDK
            if let link = payload?["link"] as? String {
                print("DezervSDK: deeplink — \(link)")
                // TODO: Navigate to this deeplink in your app
            }

        case .analytics:
            // Forward to your analytics service
            let eventName = payload?["eventName"] as? String ?? ""
            print("DezervSDK: analytics — \(eventName)")
            // TODO: Forward to your analytics (e.g. Firebase, Mixpanel)

        case .themeChange:
            // SDK theme changed — sync your app's theme if needed
            let theme = payload?["theme"] as? String ?? ""  // "dark" or "light"
            print("DezervSDK: theme changed to \(theme)")

        case .dataShare:
            // SDK is sharing data with the host app — structure varies by use case
            if let sharedData = payload {
                print("DezervSDK: dataShare — \(sharedData)")
                // TODO: Process or display shared data in your app
            }

        case .error:
            // Catch-all operational error during SDK runtime
            // Codes: sdk_error | network_error | unknown_error
            let message = payload?["message"] as? String
            let code = payload?["code"] as? String
            let error = payload?["error"] as? String ?? "unknown"
            print("DezervSDK: error — message=\(message ?? "") code=\(code ?? "") error=\(error)")

        case .unknown:
            // WebView sent an unrecognized event type — log for diagnostics
            print("DezervSDK: unknown event payload — \(payload ?? [:])")

        default:
            // Internal/diagnostic events (sdkData, interceptParentScroll, OTP, etc.)
            print("DezervSDK: \(event) — \(payload ?? [:])")
        }
    }
}


// =============================================================================
// FILE 2: DezervPortfolioHostView — thin UI host only
// Create as: a new SwiftUI View file in the partner's Views/ directory
// Presents DezervSDKView after DezervSDKConfigurator.attach succeeds.
// No launcher button — the parent decides sheet / push / tab / cover.
// =============================================================================

/// Presentation phases for the thin SDK host.
enum DezervPortfolioHostPhase: Equatable {
    case loading
    case ready
    case failed(String)
}

struct DezervPortfolioHostView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var phase: DezervPortfolioHostPhase = .loading

    var body: some View {
        Group {
            switch phase {
            case .loading:
                ProgressView("Configuring SDK...")

            case .ready:
                // DezervSDKView renders the SDK WebView
                // Pass theme to override: DezervSDKView(theme: .dark)
                DezervSDKView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .failed(let message):
                Text(message)
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .task {
            attachSDK()
        }
    }

    /// Wires Builder via the configurator, then flips phase for UI only.
    private func attachSDK() {
        phase = .loading

        let callbacks = DezervSDKConfigurator.HostCallbacks(
            onDismiss: {
                dismiss()
            },
            onReinitialize: {
                // Fetch a fresh partnerAuthToken, then attach again
                attachSDK()
            },
            onHostLogout: {
                // TODO: Clear your app's own auth session
                dismiss()
            }
        )

        switch DezervSDKConfigurator.attach(callbacks: callbacks) {
        case .success:
            phase = .ready
        case .failure(let message):
            phase = .failed("SDK setup failed: \(message)")
        }
    }
}
#endif


// =============================================================================
// LOGOUT HANDLER
// Call this when the partner user logs out of the host app.
// Place in: wherever your app handles user logout (e.g. settings, auth manager)
// =============================================================================
//
// func handleUserLogout() {
//     // 1. Logout from Dezerv SDK — clears user session data
//     DezervSDK.shared.logout()
//
//     // 2. Dispose SDK resources
//     DezervSDK.shared.dispose()
//
//     // 3. Clear your app's own user session
//     // TODO: yourAppAuthService.clearSession()
// }
