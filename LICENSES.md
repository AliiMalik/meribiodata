# Third-party licenses

Every dependency in MeriBiodata must carry a permissive license (MIT / BSD / Apache-2.0 / OFL).
This file is updated in the same commit as any dependency change.

## Fonts

Bundled in `assets/fonts/`. Total bundled weight: **1.87 MB** (see NFR-8 note below).

| Font | Weights | Size | License | Source |
|---|---|---|---|---|
| Inter | Regular, SemiBold, Bold | 1252 KB | SIL OFL 1.1 | [rsms/inter](https://github.com/rsms/inter) v4.1 |
| Noto Nastaliq Urdu | Regular, Bold | 508 KB | SIL OFL 1.1 | [notofonts](https://github.com/notofonts/notofonts.github.io) |
| Noto Naskh Arabic | Regular, Bold | 527 KB | SIL OFL 1.1 | [notofonts](https://github.com/notofonts/notofonts.github.io) |

License texts ship alongside the fonts: `assets/fonts/Inter-OFL.txt`, `assets/fonts/Noto-OFL.txt`.

Usage: Inter for Latin UI chrome; Noto Nastaliq Urdu for Urdu, Punjabi (Shahmukhi), Saraiki,
Hindko and Kashmiri; Noto Naskh Arabic for Sindhi, Pashto, Balochi, Brahui and Arabic, and as the
fallback for any glyph Nastaliq lacks.

Jameel Noori Nastaleeq and similar popular-but-unclearly-licensed Urdu fonts are **deliberately
not bundled**, per the build prompt's license hygiene rule.

**Still to add:** Lora or Noto Serif (OFL) for the English document body at M3.

**NFR-8 note.** Inter's static weights are ~420 KB each because they carry Greek and Cyrillic we
never use; Inter Medium was dropped for this reason. Subsetting all three families to the
codepoints we actually render is an M6 task and should cut this figure substantially. If the
bundle still looks heavy after subsetting, downloadable per-language font packs are the
next lever (§4) — but they trade against the offline-first promise, so that is a discussion, not
a default.

## Dart / Flutter packages

### Runtime

| Package | Version | License |
|---|---|---|
| flutter_image_compress | 2.5.1 | MIT |
| flutter_secure_storage | 10.3.1 | BSD-3-Clause |
| freezed_annotation | 3.1.0 | MIT |
| go_router | 17.3.0 | BSD-3-Clause |
| google_mobile_ads | 9.0.0 | Apache-2.0 |
| hive_ce | 2.19.3 | Apache-2.0 |
| hive_ce_flutter | 2.3.4 | Apache-2.0 |
| intl | (resolved by flutter_localizations) | BSD-3-Clause |
| json_annotation | 4.12.0 | BSD-3-Clause |
| path_provider | 2.1.6 | BSD-3-Clause |
| pdf | 3.13.0 | Apache-2.0 |
| printing | 5.15.0 | Apache-2.0 |
| provider | 6.1.5+1 | MIT |
| share_plus | 13.3.0 | BSD-3-Clause |
| url_launcher | 6.3.2 | BSD-3-Clause |
| uuid | 4.6.0 | MIT |

**Transitive note:** `google_mobile_ads` pulls in `webview_flutter` (BSD-3-Clause), because ads
render in a webview. The app itself never embeds one — the waitlist form opens in the external
browser by design (`docs/decisions.md` D8), and CI enforces that.

### Build-time only (not shipped in the APK)

| Package | Version | License |
|---|---|---|
| build_runner | 2.15.1 | BSD-3-Clause |
| freezed | 3.2.5 | MIT |
| json_serializable | 6.14.1 | BSD-3-Clause |
| very_good_analysis | 10.3.0 | MIT |

### Evaluated and rejected

| Package | Outcome |
|---|---|
| arabic_reshaper (MIT) | Evaluated in M0. Not carried forward — the presentation-forms approach it implements is unusable for Nastaliq. See `docs/spike-nastaliq.md`. |
| hive_ce_generator (Apache-2.0) | Dropped. Its analyzer constraint forces a prerelease `freezed`, and storing JSON documents is a better fit for a schema-driven field engine. See `docs/decisions.md` D2. |

### Expected later

Image-picking and crypto packages at M5.

Note: `printing` is used only for its PDF plumbing. `Printing.convertHtml` — the M0
Pipeline C route — is deprecated and broken on Android, and is not called anywhere.
