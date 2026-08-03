# Third-party licenses

Every dependency in MeriBiodata must carry a permissive license (MIT / BSD / Apache-2.0 / OFL).
This file is updated in the same commit as any dependency change.

## Fonts

| Font | License | Source | Used for |
|---|---|---|---|
| Noto Nastaliq Urdu | SIL OFL 1.1 | [notofonts/nastaliq](https://github.com/notofonts/notofonts.github.io) | Urdu, Punjabi (Shahmukhi), Saraiki, Hindko, Kashmiri |
| Noto Naskh Arabic | SIL OFL 1.1 | [notofonts/arabic](https://github.com/notofonts/notofonts.github.io) | Sindhi, Pashto, Balochi, Brahui, Arabic; fallback for glyphs Nastaliq lacks |

Full OFL text: `spike/nastaliq_spike/assets/fonts/OFL.txt` (moves to `assets/fonts/OFL.txt` at M1).

Jameel Noori Nastaleeq and similar popular-but-unclearly-licensed Urdu fonts are **deliberately
not bundled**, per the build prompt's license hygiene rule.

Still to add at M1: **Inter** (UI, OFL) and **Lora** or **Noto Serif** (English document body, OFL).

## Dart / Flutter packages

Current set is the M0 spike only; this table is rewritten when the M1 dependency set is fixed.

| Package | Version | License |
|---|---|---|
| pdf | 3.13.0 | Apache-2.0 |
| printing | 5.15.0 | Apache-2.0 |
| path_provider | 2.1.6 | BSD-3-Clause |
| arabic_reshaper | 0.0.1 | MIT — evaluated in M0, **not carried forward** (see `docs/spike-nastaliq.md`) |
| flutter_lints | 6.0.0 | BSD-3-Clause |
