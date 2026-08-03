# Decisions

Settled choices, with the reasoning that produced them. Append; don't rewrite history.
If a decision is reversed, add a new entry that supersedes the old one rather than editing it.

---

## D1 — PDF rendering pipeline: hybrid (B for Perso-Arabic, A for Latin)

**Date:** 2026-08-04 · **Decided by:** owner · **Milestone:** M0 → M3

Approved off the back of `docs/spike-nastaliq.md`.

- **Perso-Arabic document languages** (Urdu, Sindhi, Pashto, Punjabi/Shahmukhi, and all P2
  languages) render via **Pipeline B** — a real Flutter widget tree captured from a
  `RepaintBoundary` and placed into the PDF as a bitmap.
- **Latin document languages** (English) render via **Pipeline A** — `pdf` package vector text.

Pipeline A is unusable for Perso-Arabic: it produces collapsed glyph piles, tofu, reversed
Latin runs and mangled digits. Pipeline C was rejected on tooling grounds, not typography —
`Printing.convertHtml` is deprecated, the Android plugin never reports the capability, and its
implementation hangs. Blink itself shapes correctly, so C stays a viable future option.

**Consequences:** the renderer must be pipeline-pluggable per document language, driven by
`LanguageDescriptor`; both backends share one layout spec; Pipeline B needs its own pagination
because it cannot use `pw.MultiPage`.

**Still open:** native-reader sign-off on the Urdu/Sindhi/Pashto output, and a real low-end
device timing run against NFR-2.

---

## D2 — Local database: Hive CE

**Date:** 2026-08-04 · **Decided by:** owner · **Milestone:** M1

**Owner's choice, overriding the build prompt's Drift + SQLCipher default.** We use
[`hive_ce`](https://pub.dev/packages/hive_ce), the maintained community fork — the original
`hive` package is effectively unmaintained.

Rationale for Hive: trivial API, an excellent fit for a document-shaped model, native
AES-encrypted boxes, and far less setup than Drift.

**Known trade-offs, accepted:**

- **Weaker querying.** Fine for Phase 1 — the app lists, searches and opens profiles, none of
  which needs SQL. The 9.5 restore-merge is done in memory by profile id. If Phase 2's CRM
  arrives and needs real queries, that is a migration to plan then, not now.
- **Box encryption is AES-256-CBC with a CRC32 frame checksum**, not authenticated encryption.
  This satisfies NFR-6 ("local storage encrypted; key in `flutter_secure_storage`"), but it is
  weaker than SQLCipher against deliberate tampering with the on-disk file.
- **NFR-9 is unaffected.** The `.mbd` backup file carries its own AES-256-GCM authenticated
  encryption with a password-derived key, implemented by us and independent of the DB. The DB
  key is never reused for it.

**Consequences:**

- All persisted models go through an explicit serialization layer (`LocalStore`), so the storage
  engine stays swappable and no Hive type leaks past the repository boundary. Documents are
  stored as JSON text in `Box<String>`, not as typed Hive adapters — which also means
  `hive_ce_generator` is not a dependency, and `freezed` can stay on a stable release rather than
  the prerelease that generator's analyzer constraint would have forced.

- **Hive encrypts values, not keys.** Verified on device: `preferences.hive` contains ciphertext
  for the document body but the plaintext key `app` in the frame header. Therefore **document ids
  must never carry user data** — profile ids are UUIDs, and no user-supplied string (a name, a
  phone number) may ever be used as a collection key. This is a standing rule, not a one-off.

---

## D3 — Language rollout: P0 + P1 at v1.0

**Date:** 2026-08-04 · **Decided by:** owner · **Milestone:** M3

v1.0 ships English, Urdu, Roman Urdu (UI locale only), Sindhi, Pashto and Punjabi (Shahmukhi).
P2 languages (Saraiki, Balochi, Hindko, Brahui, Kashmiri, Arabic) follow as data-only additions.

Translation quality is the constraint, not code. Adding a language must stay a data-only change:
a new ARB file plus a `LanguageDescriptor` entry, no code changes.

**Still open:** who reviews the Sindhi, Pashto and Punjabi translations.

---

## D4 — Unlimited local biodata profiles in Phase 1

**Date:** 2026-08-04 · **Decided by:** owner · **Milestone:** M2

Confirmed. A parent may have two or three children to marry off. Create, duplicate, delete and
search over an unlimited local list. CRM features remain Phase 2 and stay unreachable in the UI.

---

## D5 — Two palette amendments for WCAG AA

**Date:** 2026-08-04 · **Decided by:** Claude, pending your review · **Milestone:** M1

§10 requires AA contrast on every text-on-surface pair. Measuring the specified palette turned up
two failures beyond the one the build prompt anticipated. Both are implemented and locked in by
`test/theme/contrast_test.dart`; **both are reversible if you prefer the original look.**

1. **Secondary Text is `#475569` (Slate-600), not `#64748B` (Slate-500).** `#64748B` measures
   **4.34:1** on the Surface colour `#F1F5F9` — below the 4.5:1 body-text threshold — and secondary
   text on cards and input fields is everywhere in this app. `#475569` measures 6.92:1 on Surface
   and 7.26:1 on Background. Same hue ramp, one step darker.

2. **Filled buttons use Primary Dark `#166534` as the container, not Primary Green `#16A34A`.**
   White on `#16A34A` is **3.30:1** — fine for large text, below AA for a 14sp button label. The
   palette values are unchanged; what changed is the *usage rule*. Primary Green keeps its role for
   active states, selection, focus rings and non-text fills.

Measured for the record: white on Warning is 2.15:1, on Success 2.28:1, on Accent Gold 2.38:1 — so
those fills carry dark text (`AppColors.onWarning` etc.), never white. Secondary Green is 1.82:1 on
Background, confirming the build prompt's own prediction that it is a fill colour only.

**If you want the original `#16A34A` buttons back**, say so — the change is one line in
`AppTheme`, and the contrast test will then need an explicit documented exemption.

---

## Still open

| # | Question | Blocks |
|---|---|---|
| 1 | Who reviews Sindhi / Pashto / Punjabi translations? | M3 |
| 2 | Waitlist mechanism: `mailto:` vs embedded third-party form — changes the privacy policy text | M4 |
| 3 | Photos: included by default in templates, or opt-in? | M5 |
| 4 | Backup password policy: enforce minimum strength, or warn only? | M5 |
| 5 | App name, package id, Play Console account — needed for real AdMob unit IDs | M4 |
| 6 | Watermark wording and prominence | M3 |
| 7 | 9.6 Boy/Girl biodata presets — build or not? | M2 |
| 8 | 9.7 Accessibility for older users — build or not? (strongly recommended) | M5.5 |

Interim: the app id is `com.meribiodata.app` until question 5 is answered. It is cheap to change
any time before the first Play upload.
