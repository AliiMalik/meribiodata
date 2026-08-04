# MeriBiodata

An offline-first, privacy-first Islamic marriage biodata (rishta CV) generator for Pakistani
families. Android only.

**The core promise, in priority order:**

1. The Urdu and regional-script output is beautiful and correct.
2. The data never leaves the phone.
3. A non-technical 55-year-old parent can complete a biodata in under ten minutes.

## Status

| Milestone | State |
|---|---|
| M0 — Nastaliq PDF spike | Complete. Pipeline chosen, awaiting native-reader sign-off. |
| M1 — Foundation | Complete. |
| M2 — Schema & form engine | Complete. |
| M3 — Templates & export | Not started. |
| M4 — Monetization & waitlist | Not started. |
| M5 — Differentiators | Not started. |
| M5.5 — Polish · M6 — Hardening | Not started. |

Per-milestone write-ups are in [`docs/progress/`](docs/progress/).

## Getting started

Requires Flutter 3.44.0 (stable) and JDK 17.

```bash
flutter pub get && flutter gen-l10n && dart run build_runner build && flutter run
```

Generated sources — localizations in `lib/l10n/generated/`, and the `freezed`/`json_serializable`
output next to each model — are not committed. CI regenerates them before analyzing, so they
cannot drift from their sources.

Before pushing:

```bash
dart format lib test && flutter analyze --fatal-infos && flutter test
```

## Architecture

```
lib/
  core/
    preferences/   app-wide settings (Provider + repository)
    router/        go_router config and route constants
    storage/       LocalStore interface + encrypted Hive implementation
    theme/         design tokens; AppColors is the only file with hex values
    widgets/       shared UI
  domain/          models and pure logic — no Flutter, no storage, no async
  data/            repositories and bundled data assets
  features/        one directory per screen, each with its own controller
  l10n/
    arb/           translation sources — the only place user-facing strings live
    generated/     gen_l10n output (git-ignored)
    language_descriptor.dart
assets/
  data/            biradari suggestions
  fonts/           Inter + Noto Nastaliq Urdu + Noto Naskh Arabic (all OFL)
  i18n/            shipped labels for built-in fields, per document language
```

Four rules that are load-bearing rather than stylistic:

- **Nothing goes to a developer-owned server, ever.** CI fails the build if an HTTP client is
  added. The only permitted network callers are the AdMob SDK and the waitlist submission.
- **No raw hex outside `AppColors`,** and every text-on-surface pair is contrast-tested.
- **No user-facing string outside an ARB file.** Adding a language must be a data-only change:
  one ARB file plus one `LanguageDescriptor` entry.
- **No storage-engine type past the repository boundary,** and document ids are always UUIDs —
  Hive encrypts values but not keys.
- **The form is data, never a widget tree.** Every field and section is a descriptor a user can
  rename, reorder, hide, delete or create. Templates render whatever schema exists, so no
  rendering code may assume any particular field is present.

## Key documents

- [`docs/decisions.md`](docs/decisions.md) — settled choices, with reasoning, and what is still open
- [`docs/spike-nastaliq.md`](docs/spike-nastaliq.md) — why Perso-Arabic PDFs are rasterized
- [`LICENSES.md`](LICENSES.md) — every dependency and font, with its license

## Scope

Phase 1 only. Matchmaker Pro exists solely as a "coming soon" waitlist screen; no CRM surface is
reachable. There is no matching, no discovery, no server-side sharing, and no account system —
these are out of scope by design, not yet to be built.
