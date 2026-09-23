# Dezerv Agent Skills

Public [Agent Skills](https://agentskills.io/) for partners integrating Dezerv products with AI coding agents (Claude Code, Cursor, GitHub Copilot, Codex, and more).

Install with the [GitHub CLI](https://cli.github.com/) (`gh skill`, v2.90.0+).

## Portfolio Tracker SDK

Skills that walk partners through setting up the Portfolio Tracker SDK on Android and iOS.

| Skill | Platform | What it covers |
|-------|----------|----------------|
| `portfolio-tracker-android-setup` | Android | Gradle, permissions, partner auth token, `partnerUserMeta`, `DezervSDKView`, Builder/`show()`, warmup, events |
| `portfolio-tracker-ios-setup` | iOS | SPM, Face ID, partner auth token, `partnerUserMeta`, `DezervSDK.Builder`, `DezervSDKView`, warmup, events |

Full API reference: [portfolio-tracker-sdk-docs](https://github.com/dezerv/portfolio-tracker-sdk-docs)

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
4. Cross-check against the [Android](https://github.com/dezerv/portfolio-tracker-sdk-docs/tree/main/docs/android) and [iOS](https://github.com/dezerv/portfolio-tracker-sdk-docs/tree/main/docs/ios) docs.

## Repository layout

```
skills/
  portfolio-tracker-android-setup/SKILL.md
  portfolio-tracker-ios-setup/SKILL.md
```

Matches the `skills/*/SKILL.md` convention that `gh skill` discovers automatically.

## Maintainers

```bash
gh skill publish --dry-run   # validate
gh skill publish             # create a release
```

## Support

- Docs: https://github.com/dezerv/portfolio-tracker-sdk-docs
- Issues: https://github.com/dezerv/Skills/issues
- Team: Dezerv Platform Engineering
