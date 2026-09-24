// =============================================================================
// Reference implementation for the Dezerv Portfolio Tracker SDK — iOS
// Adapt to the partner's existing project — do not copy verbatim.
//
// Architecture:
//   - DezervSDK.shared.initialize() → @main App struct init() ONLY (one-time warmup)
//   - DezervSDK.Builder()           → SwiftUI View (presentation layer)
//   - DezervSDK.shared.logout()     → When the partner user logs out of the host app
//   - DezervSDK.shared.dispose()    → When the SDK UI is dismissed
//
// The SDK is a SINGLETON (DezervSDK.shared). initialize() must be called
// exactly ONCE at app start. Builder + DezervSDKView is used each time
// the SDK UI needs to be presented.
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


// =============================================================================
// SDK CONTAINER VIEW — presentation layer with Builder + event handling
// Create as: a new SwiftUI View file in the partner's Views/ directory
// Wrap in #if canImport so the project builds even if the package hasn't resolved
// =============================================================================

#if canImport(PortfolioTrackerSDK)
import SwiftUI
import PortfolioTrackerSDK

struct SDKContainerView: View {
    // DezervSDK.shared.error is @Published — observe it reactively
    @StateObject private var sdk = DezervSDK.shared

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
                // DezervSDKView renders the SDK WebView
                // Pass theme to override: DezervSDKView(theme: .dark)
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

        // =====================================================================
        // 1. Auth token — MUST come from the partner backend, never hardcoded
        // =====================================================================
        let authToken = "PARTNER_AUTH_TOKEN" // TODO: Replace with your backend's /auth/token response

        // =====================================================================
        // 2. User metadata — personalization + session + attribution fields
        // See references/user-meta-fields.md for the full field table
        // =====================================================================
        let userMeta: [String: Any] = [
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

        // =====================================================================
        // 3. SDK configuration
        // =====================================================================
        let config = DezervSDKConfigParms(
            partnerAuthToken: authToken,
            partnerUserMeta: userMeta,

            // Theme — .light or .dark
            theme: .light,

            // View type:
            //   .fullView = full-screen standalone SDK view (default)
            //   .tabView  = embedded/nested view for tab-based navigation
            viewType: .fullView

            // ⚠️ PREPROD SETUP: If targeting preprod, you must change BOTH:
            //   1. DezervSDK.shared.initialize() in @main: environment: .preprod
            //   2. This config: use a preprod-issued partnerAuthToken
            //   Mismatched environments will cause auth failures or blank screens
        )

        // =====================================================================
        // 4. Build the SDK instance
        // =====================================================================
        let result = DezervSDK.Builder()
            .setConfig(config)                               // Required: SDK configuration
            .withMessageListener { event, payload in          // Optional: Event listener
                handleSDKEvent(event, payload: payload)
            }
            .build()                                         // Build the configured instance

        // =====================================================================
        // 5. Handle build result
        // =====================================================================
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

    // =========================================================================
    // Event handler — responds to SDK lifecycle and user interaction events
    // See docs: events.md for full event reference
    // =========================================================================
    // =========================================================================
    // Event handler — only the events partners need to act on
    // See docs: events.md for the full list including internal/diagnostic events
    // =========================================================================
    private func handleSDKEvent(_ event: DezervSDKEvent, payload: [String: Any]?) {
        switch event {

        case .sdkInitializationSuccess:
            // SDK WebView is loaded and ready — safe to interact
            print("DezervSDK: initialized successfully")

        case .sdkInitializationError:
            // Config or auth issue — check partnerAuthToken and userMeta
            let error = payload?["error"] as? String ?? "unknown"
            print("DezervSDK: init failed — \(error)")

        case .exit:
            // ACTION REQUIRED: dismiss the SDK view
            if let errorCode = payload?["errorCode"] as? String,
               errorCode == "sdk_error" {
                // SDK-side error — fetch a fresh auth token and re-configure
                print("DezervSDK: exit with sdk_error — re-init with new token")
            } else {
                // Normal exit — dismiss UI and release SDK resources
                DispatchQueue.main.async {
                    showSDK = false
                    DezervSDK.shared.dispose()
                }
            }

        case .logout:
            // ACTION REQUIRED: user logged out inside the SDK
            // Clear SDK state, then clear your app's session too
            DispatchQueue.main.async {
                DezervSDK.shared.logout()   // Clears SDK session data
                DezervSDK.shared.dispose()  // Releases SDK resources
                // TODO: Also clear your app's own auth session
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

        default:
            // Other events (dataShare, error, custom, OTP, etc.) — log for debugging
            print("DezervSDK: \(event) — \(payload ?? [:])")
        }
    }
}
#endif


// =============================================================================
// HOW TO LAUNCH THIS VIEW
// Uncomment the pattern that matches your app's navigation:
// =============================================================================
//
// --- Sheet (most common) ---
// @State private var showPortfolio = false
//
// Button("Open Portfolio") { showPortfolio = true }
// .sheet(isPresented: $showPortfolio) {
//     PortfolioTrackerView()
// }
//
// --- Full-screen cover ---
// .fullScreenCover(isPresented: $showPortfolio) {
//     PortfolioTrackerView()
// }
//
// --- NavigationLink (push) ---
// NavigationLink("Portfolio") {
//     PortfolioTrackerView()
// }
//
// --- Tab in TabView ---
// TabView {
//     PortfolioTrackerView()
//         .tabItem { Label("Portfolio", systemImage: "chart.line.uptrend.xyaxis") }
// }


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
