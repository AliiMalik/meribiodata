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

## D6 — The schema is per-profile, seeded from a default

**Date:** 2026-08-04 · **Decided by:** Claude, flag if you disagree · **Milestone:** M2

§6.2 describes the default schema as "seeded on first run", which reads as a single global schema.
Combined with D4 (unlimited profiles) that creates a problem: the per-field overflow menu — rename,
hide, mark sensitive, delete — lives in the **Form Editor**, which is per-profile. With a global
schema, renaming "Caste" to "Zaat" while editing one child's biodata would silently rewrite their
sibling's, and hiding a field on one would hide it everywhere. That is surprising in the worst way:
invisible until the other biodata is exported.

So: **each profile owns a complete copy of its schema**, created from a default seed when the
profile is created. "Reset to defaults" in the Schema Editor re-seeds that one profile.

**Consequences:**

- 9.6's boy/girl presets become natural — they are just a second seed, chosen at creation.
- 9.5's backup is self-contained per profile; no shared schema object to reconcile on restore.
- The cost is that a user who wants the same rename across three profiles does it three times.
  Acceptable, and arguably what they mean. If it proves annoying, "apply this schema to my other
  biodatas" is a later feature, not an architectural change.
- Schema copies are small (capped at 60 fields / 10 sections by §6.3), so duplication is cheap.

---

## D7 — Cross-language label fallback: following §6.1's order, with a caveat

**Date:** 2026-08-04 · **Decided by:** Claude, **wants your ruling** · **Milestone:** M2

§6.1 contains two rules that pull against each other:

- The resolution order puts **"user override for any language"** (step 2) *above* **"built-in i18n
  string for the active language"** (step 3).
- The prose says: *"Renaming 'Caste' to 'Zaat/Biradari' in the Urdu document must not silently
  rename it in the English document."*

Under the stated order, a user who renames a field in Urdu **will** see their Urdu words in the
English document, because English has no override of its own and step 2 fires before the shipped
English label. The two statements only reconcile if "must not silently rename" is read as *"the
stored overrides are per-language and one must not overwrite the other"* — which is exactly what
the ordering plus the §6.1 language chip implies.

**Implemented as specified.** Overrides are stored per locale, one never overwrites another, and
`LabelResolver.isBorrowedFromAnotherLanguage` tells the UI when a shown label came from a different
language so it can display the chip.

**The caveat, and why I want your ruling.** For a *built-in* field this produces an English word
inside an Urdu biodata — "Caste" where "ذات / برادری" was already available and correct. That is
precisely the kind of blemish the product exists to avoid. For a *custom* field the behaviour is
obviously right: there is no shipped label, so borrowing is the only alternative to showing a UUID.

Three options:

1. **As specified now** — step 2 always outranks the shipped label. Consistent, and the chip
   explains it. Risks English text in an Urdu document.
2. **Step 2 only for custom fields.** A built-in field with a shipped translation for the active
   language uses it; a renamed built-in falls back to the shipped label rather than to another
   language's override. Best output quality; slightly more surprising to edit.
3. **Step 2, but prompt.** On switching document language, offer "you renamed 3 fields in Urdu —
   translate them for English?" More code, best of both, M3 at the earliest.

**My recommendation is 2.** The whole product thesis is that the Urdu output is right, and a
built-in field already has a correct, reviewed translation sitting there. Option 1's failure mode
lands in the exported PDF, which is the artifact the user shares. Changing to 2 is a small edit in
`LabelResolver` and one test.

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
