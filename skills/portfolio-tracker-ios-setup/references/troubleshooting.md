# Troubleshooting — iOS SDK

Load this reference when the agent encounters build failures, runtime errors, or unexpected SDK behavior.

| Symptom | Check |
|---------|--------|
| Package not found | URL `https://github.com/dezerv/portfolio-sdk-ios`; network; remove/re-add package |
| Deployment target errors | Set iOS **15.0+**, Xcode **15+** |
| Face ID issues | `NSFaceIDUsageDescription` present; test on device |
| Auth / blank SDK | Invalid or missing `partnerAuthToken` |
| Personalization wrong | Required meta fields missing or wrong `partner_category` — see `references/user-meta-fields.md` |
| Warmup ineffective | Pass `environment: .production` or `.preprod` |
| `Builder` returns `.failure` | Check `error.code` and `error.message`; most common cause is expired/invalid auth token |
| SDK view appears but is blank | Token valid but `partnerUserMeta` missing required fields |
| Multiple init calls | `DezervSDK.shared` is a singleton — `initialize` should be called once in the `@main` struct `init()` |
