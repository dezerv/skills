# Required `partnerUserMeta` fields (Android)

Load this reference when the agent needs to verify or construct `partnerUserMeta` for `DezervSDKConfig`.

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
