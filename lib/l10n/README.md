# Localization

ARB files drive `AppLocalizations` via `flutter gen-l10n` (`l10n.yaml`).

- **en** — template / default
- **bn** — Bengali stub proving the pipeline

## Migrated so far
Account tab (title, appearance/theme), sign-in security card blurb, offline banner.

## Remaining
Most feature screens (pairing, dashboard, alerts, map, team, 2FA, onboarding, etc.) still use English string literals. Prefer `AppLocalizations.of(context)` when touching a screen.
