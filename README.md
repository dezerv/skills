# Dezerv Agent Skills

Public [Agent Skills](https://agentskills.io/) for partners integrating Dezerv products with AI coding agents (Claude Code, Cursor, GitHub Copilot, Codex, and more).

Install with the [GitHub CLI](https://cli.github.com/) (`gh skill`, v2.90.0+).

## Portfolio Tracker SDK

Skills that walk partners through setting up the Portfolio Tracker SDK on Android and iOS.

| Skill | Platform | What it covers |
|-------|----------|----------------|
| `portfolio-tracker-android-setup` | Android | Gradle, permissions, partner auth token, `partnerUserMeta`, `DezervSDKView`, Builder/`show()`, warmup, events, project-aware locate & validate |
| `portfolio-tracker-ios-setup` | iOS | SPM, Face ID, partner auth token, `partnerUserMeta`, `DezervSDK.Builder`, `DezervSDKView`, warmup, events, project-aware locate & validate |

Full API reference: [Portfolio Tracker SDK Docs](https://dezerv.github.io/portfolio-tracker-sdk-docs/)

### Install

```bash
# Both skills
gh skill install dezerv/Skills --all

# Android only
gh skill install dezerv/Skills portfolio-tracker-android-setup

# iOS only
gh skill install dezerv/Skills portfolio-tracker-ios-setup
```

Target a specific agent:

```bash
gh skill install dezerv/Skills --all --agent claude-code --scope user
gh skill install dezerv/Skills --all --agent cursor --scope project
```

Preview before installing:

```bash
gh skill preview dezerv/Skills portfolio-tracker-android-setup
```

Update installed skills:

```bash
gh skill update --all
```

### After install

1. Open your partner Android or iOS app in an agent that supports skills.
2. Ask the agent to set up the Portfolio Tracker / Dezerv SDK (or invoke the skill by name).
3. Provide a real `partnerAuthToken` when prompted — do not commit production tokens.
4. Cross-check against the [Android](https://dezerv.github.io/portfolio-tracker-sdk-docs/current/android/getting-started) and [iOS](https://dezerv.github.io/portfolio-tracker-sdk-docs/current/ios/getting-started) docs.

## Repository layout

```
skills/
  portfolio-tracker-android-setup/
    SKILL.md                          # Core setup instructions
    references/
      user-meta-fields.md            # partnerUserMeta field table (loaded on demand)
      troubleshooting.md             # Symptom → fix lookup (loaded on demand)
    scripts/
      validate-integration.sh        # Automated integration checks (8 checks)
  portfolio-tracker-ios-setup/
    SKILL.md                          # Core setup instructions
    references/
      user-meta-fields.md            # partnerUserMeta field table (loaded on demand)
      troubleshooting.md             # Symptom → fix lookup (loaded on demand)
    scripts/
      validate-integration.sh        # Automated integration checks (7 checks)
```

Matches the `skills/*/SKILL.md` convention that `gh skill` discovers automatically. Reference files use progressive disclosure — the agent loads them only when needed, keeping the core skill under 500 lines.

## Maintainers

```bash
gh skill publish --dry-run   # validate
gh skill publish             # create a release
```

## Support

- Docs: https://dezerv.github.io/portfolio-tracker-sdk-docs/
- Issues: https://github.com/dezerv/Skills/issues
- Team: Dezerv Engineering
