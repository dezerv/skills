// =============================================================================
// Reference implementation for the Dezerv Portfolio Tracker SDK — Android
// Adapt to the partner's existing project — do not copy verbatim.
//
// Architecture:
//   - DezervSDK.initialize() → Application.onCreate() ONLY (one-time warmup)
//   - DezervSDK.Builder()    → Activity or Fragment (presentation layer)
//   - DezervSDK.logout()     → When the partner user logs out of the host app
//
// The SDK is a singleton. initialize() must be called exactly ONCE at app start.
// Builder + show() is called each time the SDK UI needs to be presented.
// =============================================================================

// =============================================================================
// FILE 1: Application class — SDK warmup (root-level, one-time only)
// Place in: your app's Application subclass (e.g. MyApplication.kt)
// =============================================================================

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

        // SDK requires Android 13 (API 33) or higher
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {

            // Initialize the SDK ONCE at app startup for warmup/pre-loading.
            // This is async and non-blocking — safe to call in onCreate().
            // Match theme and viewType with what you'll use in DezervSDKConfig later.
            DezervSDK.initialize(
                context = this,
                dezervSDKInitConfig = DezervSDKInitConfig(
                    // Theme must match the theme used in DezervSDKConfig for optimal perf
                    theme = DezervSDKTheme.light,

                    // FULL_VIEW = full-screen SDK view (default)
                    // TAB_VIEW  = embedded/nested SDK view (for tab-based or fragment navigation)
                    viewType = DezervViewType.FULL_VIEW,

                    // Enable debug logging during development
                    isDebug = BuildConfig.DEBUG,

                    // PRODUCTION or PREPROD — essential for warmup pre-load URL
                    // If omitted, defaults to PRODUCTION
                    // ⚠️ If using PREPROD, also pass PREPROD in DezervSDKConfig
                    //    and use a preprod auth token — they must all match
                    environment = DezervSDKEnvironment.PRODUCTION
                )
            )
        }
    }
}

// Don't forget to register in AndroidManifest.xml:
// <application android:name=".MyApplication" ... >


// =============================================================================
// FILE 2: Activity — SDK presentation (Builder + show)
// Place in: a dedicated Activity or existing Activity that will host the SDK
// The Activity MUST extend FragmentActivity or AppCompatActivity
// =============================================================================

import android.os.Build
import android.os.Bundle
import android.util.Log
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import `in`.dezerv.portfolio_tracker_sdk.DezervSDK
import `in`.dezerv.portfolio_tracker_sdk.DezervSDKView
import `in`.dezerv.portfolio_tracker_sdk.core.DezervSDKConfig
import `in`.dezerv.portfolio_tracker_sdk.core.DezervSDKEvent
import `in`.dezerv.portfolio_tracker_sdk.core.DezervSDKTheme
import `in`.dezerv.portfolio_tracker_sdk.core.DezervViewType
import kotlinx.coroutines.launch
import org.json.JSONObject

class PortfolioActivity : AppCompatActivity() {

    // Hold a reference to the SDK instance for cleanup
    private var dezervSDKInstance: DezervSDK? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_portfolio)

        // SDK requires Android 13 (API 33) — show fallback for older devices
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            Toast.makeText(this, "SDK requires Android 13 or higher", Toast.LENGTH_LONG).show()
            return
        }

        // Bind the DezervSDKView from the XML layout
        val dezervSDKView: DezervSDKView = findViewById(R.id.dezervSDKView)

        // =========================================================================
        // 1. Auth token — MUST come from the partner backend, never hardcoded
        // =========================================================================
        val authToken = "PARTNER_AUTH_TOKEN" // TODO: Replace with your backend's /auth/token response

        // =========================================================================
        // 2. User metadata — personalization + session + attribution fields
        // See references/user-meta-fields.md for the full field table
        // =========================================================================
        val userMeta = JSONObject().apply {
            // --- Session / analytics (required) ---
            put("session_id", "REPLACE_SESSION_ID")        // TODO: Replace with unique session ID
            put("schema_version", "2.0")                    // Always send "2.0"
            put("partner", "REPLACE_PARTNER_ID")            // TODO: Replace with your partner ID (e.g. "moneycontrol")

            // --- Personalization (required) ---
            // partner_category: stock | mutual_fund | index | commodity | ipo | news | homepage | comms | portfolio
            put("partner_category", "stock")
            put("partner_symbol", "RELIANCE")               // Empty string "" when category is homepage or news
            put("partner_page_title", "Reliance Industries Share Price")
            put("partner_image_text", "Track your portfolio in one place")
            // put("partner_keywords", listOf("tag1"))      // Required when partner_category == "news"

            // --- Recommended attribution ---
            put("partner_source", "home_tab")               // Internal navigation source
            put("partner_page_url", "https://partner.com/stocks/reliance-industries")
            put("partner_campaign", "example_campaign")     // Campaign identifier

            // --- Optional fields ---
            // put("phone", "9898989898")                   // User's phone number
            // put("pan", "ABCDE1234F")                     // User's PAN
            // put("deeplink", "")                          // In-SDK route to navigate to
            // put("sdkMetrics", JSONObject().apply {        // Timestamps of the /auth/token API call
            //     put("startTime", 0.0)
            //     put("endTime", 0.0)
            // })
            // put("partner_section_name", "Top Gainers")   // Section name on the partner page
            // put("partner_cta_copy", "Stop Guessing, Get wealth review by an Expert")
            // put("partner_cta_position", "hero")          // hero | inline | sticky
            // put("partner_medium", "app")                 // app | whatsapp
        }

        // =========================================================================
        // 3. SDK configuration
        // =========================================================================
        val config = DezervSDKConfig(
            partnerAuthToken = authToken,
            partnerUserMeta = userMeta,

            // Theme — must match the theme used in DezervSDK.initialize() for best perf
            theme = DezervSDKTheme.light,                   // or DezervSDKTheme.dark

            // View type:
            //   FULL_VIEW = full-screen standalone SDK view (default)
            //   TAB_VIEW  = embedded/nested view for tab-based or fragment navigation
            viewType = DezervViewType.FULL_VIEW,

            // Debug logging — use BuildConfig.DEBUG so it's auto-disabled in release
            isDebug = BuildConfig.DEBUG

            // ⚠️ PREPROD SETUP: If targeting preprod, you must change BOTH:
            //   1. DezervSDK.initialize() in Application: environment = DezervSDKEnvironment.PREPROD
            //   2. This config: use a preprod-issued partnerAuthToken
            //   Mismatched environments will cause auth failures or blank screens
        )

        // =========================================================================
        // 4. Build the SDK instance and bind to the view
        // =========================================================================
        dezervSDKInstance = DezervSDK.Builder(this)          // Must pass FragmentActivity
            .setConfig(config)                               // Required: SDK configuration
            .withView(dezervSDKView)                          // Required: Bind to DezervSDKView
            .withMessageListener { event, payload ->          // Optional: Event listener
                handleSDKEvent(event, payload)
            }
            .build()                                         // Build the configured instance

        // =========================================================================
        // 5. Show the SDK UI
        // =========================================================================
        dezervSDKInstance?.show()
    }

    // =========================================================================
    // Event handler — only the events partners need to act on
    // See docs: events.md for the full list including internal/diagnostic events
    // =========================================================================
    private fun handleSDKEvent(event: DezervSDKEvent, payload: JSONObject?) {
        lifecycleScope.launch {
            when (event) {

                DezervSDKEvent.sdkInitializationSuccess -> {
                    // SDK WebView is loaded and ready — safe to interact
                    Log.d("DezervSDK", "Initialized successfully")
                }

                DezervSDKEvent.sdkInitializationError -> {
                    // Config or auth issue — check partnerAuthToken and userMeta
                    val error = payload?.optString("error") ?: "unknown"
                    Log.e("DezervSDK", "Init failed: $error")
                }

                DezervSDKEvent.exit -> {
                    // ACTION REQUIRED: dismiss the SDK view
                    val errorCode = payload?.optString("errorCode")
                    if (errorCode == "sdk_error") {
                        // SDK-side error — fetch a fresh auth token and re-configure
                        Log.e("DezervSDK", "Exit with sdk_error — re-init with new token")
                    } else {
                        // Normal exit — close the Activity
                        finish()
                    }
                }

                DezervSDKEvent.userAuth -> {
                    // User authenticated — payload has phone, flow, clientId, deviceId
                    val phone = payload?.optString("phone") ?: ""
                    val flow = payload?.optString("flow") ?: ""     // "signup" or "login"
                    Log.d("DezervSDK", "UserAuth: flow=$flow phone=$phone")
                }

                DezervSDKEvent.onDeeplink -> {
                    // User tapped a deeplink inside the SDK
                    val link = payload?.optString("link")
                    Log.d("DezervSDK", "Deeplink: $link")
                    // TODO: Navigate to this deeplink in your app
                }

                DezervSDKEvent.analytics -> {
                    // Forward to your analytics service
                    val eventName = payload?.optString("eventName") ?: ""
                    Log.d("DezervSDK", "Analytics: $eventName")
                    // TODO: Forward to your analytics (e.g. Firebase, Mixpanel)
                }

                DezervSDKEvent.themeChange -> {
                    // SDK theme changed — sync your app's theme if needed
                    val theme = payload?.optString("theme") ?: ""   // "dark" or "light"
                    Log.d("DezervSDK", "Theme changed to: $theme")
                }

                else -> {
                    // Other events (dataShare, error, custom, etc.) — log for debugging
                    Log.d("DezervSDK", "Event: $event, payload: $payload")
                }
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        // Release the SDK instance when the Activity is destroyed
        dezervSDKInstance = null
    }
}


// =============================================================================
// FILE 3: Logout handler
// Call this when the partner user logs out of the host app.
// Place in: wherever your app handles user logout (e.g. settings, auth manager)
// =============================================================================

fun handleUserLogout() {
    // 1. Logout from Dezerv SDK — clears user session data and cookies
    DezervSDK.logout()

    // 2. Clear your app's own user session
    // TODO: yourAppAuthService.clearSession()
}


// =============================================================================
// LAYOUT: activity_portfolio.xml
// =============================================================================
//
// <?xml version="1.0" encoding="utf-8"?>
// <androidx.constraintlayout.widget.ConstraintLayout
//     xmlns:android="http://schemas.android.com/apk/res/android"
//     xmlns:app="http://schemas.android.com/apk/res-auto"
//     android:layout_width="match_parent"
//     android:layout_height="match_parent">
//
//     <in.dezerv.portfolio_tracker_sdk.DezervSDKView
//         android:id="@+id/dezervSDKView"
//         android:layout_width="match_parent"
//         android:layout_height="match_parent"
//         app:layout_constraintTop_toTopOf="parent"
//         app:layout_constraintBottom_toBottomOf="parent"
//         app:layout_constraintStart_toStartOf="parent"
//         app:layout_constraintEnd_toEndOf="parent" />
//
// </androidx.constraintlayout.widget.ConstraintLayout>


// =============================================================================
// HOW TO LAUNCH THIS ACTIVITY
// Uncomment the pattern that matches your app's navigation:
// =============================================================================
//
// --- From another Activity (Intent) ---
// startActivity(Intent(this, PortfolioActivity::class.java))
//
// --- From a Composable (most common for Compose apps) ---
// val context = LocalContext.current
// Button(onClick = {
//     context.startActivity(Intent(context, PortfolioActivity::class.java))
// }) {
//     Text("Open Portfolio")
// }
//
// --- From a Fragment ---
// startActivity(Intent(requireContext(), PortfolioActivity::class.java))
//
// --- With Jetpack Navigation (nav graph) ---
// // In your nav graph:
// activity("portfolio") {
//     activityClass = PortfolioActivity::class
// }
// // Then navigate:
// navController.navigate("portfolio")


// =============================================================================
// FRAGMENT variant (for TAB_VIEW / embedded navigation)
// =============================================================================
//
// class PortfolioFragment : Fragment() {
//     private var dezervSDKInstance: DezervSDK? = null
//
//     override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
//         super.onViewCreated(view, savedInstanceState)
//
//         if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
//             val dezervSDKView: DezervSDKView = view.findViewById(R.id.dezervSDKView)
//             val activity = requireActivity() as FragmentActivity
//
//             val config = DezervSDKConfig(
//                 partnerAuthToken = "PARTNER_AUTH_TOKEN",
//                 partnerUserMeta = buildUserMeta(),
//                 theme = DezervSDKTheme.light,
//                 viewType = DezervViewType.TAB_VIEW,       // TAB_VIEW for fragment/tab usage
//                 isDebug = BuildConfig.DEBUG
//             )
//
//             dezervSDKInstance = DezervSDK.Builder(activity)
//                 .setConfig(config)
//                 .withView(dezervSDKView)
//                 .withMessageListener { event, payload -> handleSDKEvent(event, payload) }
//                 .build()
//
//             dezervSDKInstance?.show()
//         }
//     }
//
//     override fun onDestroyView() {
//         super.onDestroyView()
//         dezervSDKInstance = null
//     }
// }
