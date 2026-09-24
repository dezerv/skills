// Reference implementation for the SDK presentation view.
// Adapt to the partner's navigation structure — do not copy verbatim.

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
            theme: .light,
            viewType: .fullView
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
