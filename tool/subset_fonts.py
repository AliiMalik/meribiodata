# -*- coding: utf-8 -*-
"""Cuts the bundled fonts down to the scripts this app actually renders.

Checked in and re-runnable, because the safe way to subset is by *Unicode
range*, not by the strings currently in the app. Subsetting to today's strings
would work perfectly until a user typed a letter nobody had thought of, and
then render tofu — the exact failure `test/render/glyph_coverage_test.dart`
exists to prevent. That test is the check on this script: it walks the real
alphabet of every supported language against the shipped files.

Run:  python tool/subset_fonts.py
"""

import os
import shutil
import subprocess
import sys

ROOT = os.path.join(os.path.dirname(__file__), '..')
FONTS = os.path.join(ROOT, 'assets', 'fonts')
# Outside assets/, so the pristine copies are never bundled into the APK.
ORIGINALS = os.path.join(ROOT, 'tool', 'font-originals')

# Everything Perso-Arabic that any of the twelve supported languages can reach.
# Deliberately whole blocks rather than a letter list: Sindhi, Pashto, Balochi,
# Brahui, Saraiki, Kashmiri and Punjabi each add their own letters, and the cost
# of keeping a block is far smaller than the cost of discovering a gap in the
# field.
ARABIC = (
    'U+0600-06FF,'    # Arabic
    'U+0750-077F,'    # Arabic Supplement (Sindhi, Pashto, African)
    'U+08A0-08FF,'    # Arabic Extended-A (Punjabi, Saraiki, Kashmiri)
    'U+FB50-FDFF,'    # Presentation Forms-A
    'U+FE70-FEFF,'    # Presentation Forms-B
    'U+200C-200F,'    # ZWNJ, ZWJ, LRM, RLM
    'U+2066-2069,'    # bidi isolates, used for phone numbers in RTL
    'U+0020-007E,'    # ASCII, so an English word inside Urdu prose still sets
    'U+00A0,U+00AB,U+00BB,U+2010-2015,U+2018-201F,U+2026,U+060C,U+061B,U+061F'
)

# Latin for the UI and for English documents. What goes is Greek and Cyrillic,
# which is where Inter's weight actually is and which this app never renders.
LATIN = (
    'U+0000-00FF,'    # Basic Latin + Latin-1 Supplement
    'U+0100-017F,'    # Latin Extended-A
    'U+2010-2027,'    # dashes, quotes, ellipsis
    'U+2030-205E,'    # per-mille, primes, bullets
    'U+20A0-20BF,'    # currency symbols, including the rupee sign
    'U+2122,U+2190-2193,U+2212,U+25CF,U+FEFF'
)

TARGETS = [
    ('Inter-Regular.ttf', LATIN),
    ('Inter-SemiBold.ttf', LATIN),
    ('Inter-Bold.ttf', LATIN),
    ('NotoNastaliqUrdu-Regular.ttf', ARABIC),
    ('NotoNastaliqUrdu-Bold.ttf', ARABIC),
    ('NotoNaskhArabic-Regular.ttf', ARABIC),
    ('NotoNaskhArabic-Bold.ttf', ARABIC),
]


def main():
    os.makedirs(ORIGINALS, exist_ok=True)
    total_before = total_after = 0

    for name, unicodes in TARGETS:
        live = os.path.join(FONTS, name)
        pristine = os.path.join(ORIGINALS, name)

        # Keep the untouched file so this is repeatable: subsetting an already
        # subsetted font would compound, and there would be no way back.
        if not os.path.exists(pristine):
            shutil.copy2(live, pristine)

        before = os.path.getsize(pristine)

        subprocess.run(
            [
                sys.executable, '-m', 'fontTools.subset', pristine,
                '--unicodes=' + unicodes,
                '--output-file=' + live,
                # Shaping is the whole point of these faces. Nastaliq needs its
                # contextual alternates, ligatures, marks and kerning, and
                # dropping a feature here would break joining rather than merely
                # losing a glyph — so every layout feature is kept.
                '--layout-features=*',
                '--glyph-names',
                '--notdef-outline',
                '--recommended-glyphs',
                '--name-IDs=*',
                '--drop-tables+=DSIG',
            ],
            check=True,
            capture_output=True,
        )

        after = os.path.getsize(live)
        total_before += before
        total_after += after
        print('{:<32} {:>8} -> {:>8}  ({:+.0f}%)'.format(
            name, before, after, (after - before) / before * 100))

    print('-' * 62)
    print('{:<32} {:>8} -> {:>8}  ({:+.0f}%)'.format(
        'total', total_before, total_after,
        (total_after - total_before) / total_before * 100))


if __name__ == '__main__':
    main()
