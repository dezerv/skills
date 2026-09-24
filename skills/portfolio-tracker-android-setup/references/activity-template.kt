// Reference implementation for the SDK hosting Activity.
// Adapt to the partner's existing Activity — do not copy verbatim.

import android.os.Build
import android.os.Bundle
import android.util.Log
import androidx.appcompat.app.AppCompatActivity
import `in`.dezerv.portfolio_tracker_sdk.DezervSDK
import `in`.dezerv.portfolio_tracker_sdk.DezervSDKView
import `in`.dezerv.portfolio_tracker_sdk.core.DezervSDKConfig
import `in`.dezerv.portfolio_tracker_sdk.core.DezervSDKEvent
import `in`.dezerv.portfolio_tracker_sdk.core.DezervSDKTheme
import `in`.dezerv.portfolio_tracker_sdk.core.DezervViewType
import org.json.JSONObject

class PortfolioActivity : AppCompatActivity() {
    private var dezervSDKInstance: DezervSDK? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_portfolio)

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            // SDK requires Android 13+
            return
        }

        val dezervSDKView: DezervSDKView = findViewById(R.id.dezervSDKView)

        // Replace with JWT from partner backend
        val authToken = "PARTNER_AUTH_TOKEN"

        val userMeta = JSONObject().apply {
            // Session / analytics (required)
            put("session_id", "REPLACE_SESSION_ID")
            put("schema_version", "2.0")
            put("partner", "REPLACE_PARTNER_ID") // e.g. moneycontrol

            // Personalization (required)
            put("partner_category", "stock") // stock|mutual_fund|index|commodity|ipo|news|homepage|comms|portfolio
            put("partner_symbol", "RELIANCE") // empty string when category is homepage or news
            put("partner_page_title", "Reliance Industries Share Price")
            put("partner_image_text", "Track your portfolio in one place")
            // put("partner_keywords", listOf("tag1")) // required when partner_category == news

            // Recommended attribution
            put("partner_source", "home_tab")
            put("partner_page_url", "https://partner.com/stocks/reliance-industries")
            put("partner_campaign", "example_campaign")

            // Optional
            // put("phone", "9898989898")
            // put("pan", "ABCDE1234F")
            // put("deeplink", "")
            // put("sdkMetrics", JSONObject().put("startTime", 0.0).put("endTime", 0.0))
            // put("partner_section_name", "Top Gainers")
            // put("partner_cta_copy", "Stop Guessing, Get wealth review by an Expert")
            // put("partner_cta_position", "hero") // hero|inline|sticky
            // put("partner_medium", "app") // app|whatsapp
        }

        val config = DezervSDKConfig(
            partnerAuthToken = authToken,
            partnerUserMeta = userMeta,
            theme = DezervSDKTheme.light,
            viewType = DezervViewType.FULL_VIEW,
            isDebug = BuildConfig.DEBUG
        )

        dezervSDKInstance = DezervSDK.Builder(this)
            .setConfig(config)
            .withView(dezervSDKView)
            .withMessageListener { event, payload ->
                when (event) {
                    DezervSDKEvent.sdkInitializationSuccess ->
                        Log.d("DezervSDK", "initialized")
                    DezervSDKEvent.sdkInitializationError ->
                        Log.e("DezervSDK", "init error: ${payload?.optString("error")}")
                    DezervSDKEvent.sdkWarmupComplete ->
                        Log.d("DezervSDK", "warmup complete")
                    DezervSDKEvent.exit -> {
                        val errorCode = payload?.optString("errorCode")
                        if (errorCode == "sdk_error") {
                            Log.e("DezervSDK", "exit due to sdk_error — re-init needed")
                        } else {
                            finish()
                        }
                    }
                    DezervSDKEvent.userAuth ->
                        Log.d("DezervSDK", "userAuth: $payload")
                    DezervSDKEvent.setUserId ->
                        Log.d("DezervSDK", "userId: ${payload?.optString("userId")}")
                    DezervSDKEvent.onDeeplink ->
                        Log.d("DezervSDK", "deeplink: ${payload?.optString("link")}")
                    DezervSDKEvent.analytics ->
                        Log.d("DezervSDK", "analytics: $payload")
                    DezervSDKEvent.themeChange ->
                        Log.d("DezervSDK", "theme: ${payload?.optString("theme")}")
                    else -> Log.d("DezervSDK", "event=$event payload=$payload")
                }
            }
            .build()

        dezervSDKInstance?.show()
    }

    override fun onDestroy() {
        super.onDestroy()
        dezervSDKInstance = null
    }
}
