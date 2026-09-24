# Troubleshooting — Android SDK

Load this reference when the agent encounters build failures, runtime errors, or unexpected SDK behavior.

| Symptom | Check |
|---------|--------|
| Dependency not found | `google()` + `mavenCentral()` in repositories; version `0.8.6` |
| Crash / no UI below API 33 | Gate on `TIRAMISU`; show fallback message |
| Auth / blank SDK | Invalid or missing `partnerAuthToken`; confirm backend JWT |
| Personalization wrong | Required meta fields missing or wrong `partner_category` — see `references/user-meta-fields.md` |
| Warmup slow / no benefit | Pass `environment`; match theme between warmup and `DezervSDKConfig` |
| Release minify issues | Check ProGuard rules — see ProGuard section in SKILL.md |
| `Builder.build()` throws | Activity must be `FragmentActivity` or subclass (`AppCompatActivity`) |
| SDK view appears but is blank | Token valid but `partnerUserMeta` missing required fields |
| Keyboard overlaps SDK content | SDK auto-resizes WebView (0.8.5+); check for conflicting `windowSoftInputMode` in manifest |
| Multiple init calls | `DezervSDK.initialize` should be called once in `Application.onCreate()` |

## Error codes

| Code | Description |
|------|-------------|
| `sdk_error` | An unexpected SDK error occurred |
| `network_error` | Network connectivity issues |
| `unknown_error` | Unknown error occurred |
