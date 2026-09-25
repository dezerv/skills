// =============================================================================
// Reference implementation for the Dezerv Portfolio Tracker SDK — iOS
// Adapt to the partner's existing project — do not copy verbatim.
// Source of truth for API shapes: portfolio-tracker-sdk-docs/docs/ios/usage.md
//
// Architecture (UI and SDK wiring are separated):
//   - DezervSDK.shared.initialize(environment:) → @main App init ONLY (warmup)
//   - DezervSDKConfigurator                      → config, Builder, events (no UI)
//   - DezervPortfolioHostView                    → thin host that presents DezervSDKView
//   - DezervSDK.shared.logout() / dispose()      → host logout / dismiss
//
// Docs notes:
//   - environment is passed ONLY to initialize() — NOT on DezervSDKConfigParms
//   - theme / viewType on warmup should match DezervSDKConfigParms (best practice)
//   - partnerAuthToken must be issued for the same environment as initialize()
// =============================================================================


// =============================================================================
// WARMUP — goes in the @main App struct init(), NOT in a View
// Docs: ios/usage.md → "Optimization - SDK Warmup" / "Environment Management"
//
// IMPORTANT: Copy these comments into the partner's root file. Do not strip them.
// =============================================================================
//
// import PortfolioTrackerSDK
//
// @main
// struct MyApp: App {
//     init() {
//         // ... existing init code ...
//
//         // Pre-warm SDK during app launch (docs: Best Practices → Early Warmup).
//         // Asynchronous / non-blocking — safe at startup.
//         //
//         // environment is ESSENTIAL for warmup pre-load (docs).
//         // Pass it only here on initialize() — NOT on DezervSDKConfigParms.
//         // Allowed: .production or .preprod (.integration is Dezerv-internal only).
//         // If omitted, SDK defaults to .production.
//         //
//         // ⚠️ ALWAYS THE SAME:
//         //   1. environment below
//         //   2. partnerAuthToken issued for that same environment
//         //   3. theme / viewType here must match DezervSDKConfigParms later
//         DezervSDK.shared.initialize(
//             environment: DezervPartnerSDKSettings.environment  // .production or .preprod
//         )
//
//         // Optional: with completion handler for logging/metrics (docs)
//         // DezervSDK.shared.initialize(environment: DezervPartnerSDKSettings.environment) { result in
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
// SHARED SETTINGS — keep warmup (initialize) and display (Builder) aligned
// Docs: environment only on initialize(); theme must match warmup ↔ config
// =============================================================================

/// Single place to change env / theme / viewType so warmup and display never diverge.
enum DezervPartnerSDKSettings {
    /// Passed ONLY to `DezervSDK.shared.initialize(environment:)`.
    /// Docs: essential for warmup pre-load. partnerAuthToken must target this same env.
    static let environment: DezervSDKEnvironment = .production // TODO: .production or .preprod

    /// Must match between warmup and `DezervSDKConfigParms.theme` (docs best practice).
    static let theme: DezervSDKTheme = .light // TODO: .light or .dark

    /// `.fullView` (sheet/push/cover) or `.tabView` (embedded tab). Docs: DezervViewType.
    static let viewType: DezervViewType = .fullView // TODO: .fullView or .tabView
}

// =============================================================================
// FILE 1: DezervSDKConfigurator — SDK wiring only (no SwiftUI)
// Docs: ios/usage.md → Builder / DezervSDKConfigParms
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

    /// Configures `DezervSDK.Builder` and registers the event listener.
    /// On success the host should present `DezervSDKView()`.
    @discardableResult
    static func attach(callbacks: HostCallbacks) -> AttachResult {
        // Auth token MUST be issued for the same environment passed to initialize()
        // (DezervPartnerSDKSettings.environment). Docs: environment is set only on warmup.
        let authToken = "PARTNER_AUTH_TOKEN" // TODO: backend /auth/token for THIS environment

        // Docs struct:
        //   DezervSDKConfigParms(partnerAuthToken, partnerUserMeta, theme?, viewType?)
        // Environment is NOT a field here.
        let config = DezervSDKConfigParms(
            partnerAuthToken: authToken,
            partnerUserMeta: buildUserMeta(),

            // Theme — must match warmup (docs: Match Themes Between Warmup and Display)
            theme: DezervPartnerSDKSettings.theme,

            // View type — .fullView or .tabView (docs)
            viewType: DezervPartnerSDKSettings.viewType
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
    // See references/user-meta-fields.md / docs ios usage.md
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
    // -------------------------------------------------------------------------

    private static func handleSDKEvent(
        _ event: DezervSDKEvent,
        payload: [String: Any]?,
        callbacks: HostCallbacks
    ) {
        switch event {

        case .sdkInitializationSuccess:
            print("DezervSDK: initialized successfully")

        case .sdkInitializationError:
            let error = payload?["error"] as? String ?? "unknown"
            print("DezervSDK: init failed — \(error)")

        case .exit:
            if let errorCode = payload?["errorCode"] as? String,
               errorCode == "sdk_error" {
                print("DezervSDK: exit with sdk_error — re-init with new token")
                DispatchQueue.main.async {
                    callbacks.onReinitialize()
                }
            } else {
                DispatchQueue.main.async {
                    DezervSDK.shared.dispose()
                    callbacks.onDismiss()
                }
            }

        case .logout:
            DispatchQueue.main.async {
                DezervSDK.shared.logout()
                DezervSDK.shared.dispose()
                callbacks.onHostLogout()
            }

        case .userAuth:
            let phone = payload?["phone"] as? String ?? ""
            let flow = payload?["flow"] as? String ?? ""
            print("DezervSDK: userAuth flow=\(flow) phone=\(phone)")

        case .onDeeplink:
            if let link = payload?["link"] as? String {
                print("DezervSDK: deeplink — \(link)")
                // TODO: Navigate to this deeplink in your app
            }

        case .analytics:
            let eventName = payload?["eventName"] as? String ?? ""
            print("DezervSDK: analytics — \(eventName)")
            // TODO: Forward to your analytics (e.g. Firebase, Mixpanel)

        case .themeChange:
            let theme = payload?["theme"] as? String ?? ""
            print("DezervSDK: theme changed to \(theme)")

        case .dataShare:
            if let sharedData = payload {
                print("DezervSDK: dataShare — \(sharedData)")
                // TODO: Process or display shared data in your app
            }

        case .error:
            let message = payload?["message"] as? String
            let code = payload?["code"] as? String
            let error = payload?["error"] as? String ?? "unknown"
            print("DezervSDK: error — message=\(message ?? "") code=\(code ?? "") error=\(error)")

        case .unknown:
            print("DezervSDK: unknown event payload — \(payload ?? [:])")

        default:
            print("DezervSDK: \(event) — \(payload ?? [:])")
        }
    }
}


// =============================================================================
// FILE 2: DezervPortfolioHostView — thin UI host only
// No launcher button — parent decides sheet / push / tab / cover (SKILL Step 5b)
// =============================================================================

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
                // Docs: DezervSDKView() — optional theme override: DezervSDKView(theme: .dark)
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

    private func attachSDK() {
        phase = .loading

        let callbacks = DezervSDKConfigurator.HostCallbacks(
            onDismiss: { dismiss() },
            onReinitialize: { attachSDK() },
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
// LOGOUT HANDLER — docs: ios/usage.md logout section
// =============================================================================
//
// func handleUserLogout() {
//     DezervSDK.shared.logout()
//     DezervSDK.shared.dispose()
//     // TODO: yourAppAuthService.clearSession()
// }
