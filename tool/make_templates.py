# -*- coding: utf-8 -*-
"""Turns the supplied border artwork into shippable template backgrounds.

    python tool/make_templates.py

Reads the originals from tool/template-originals/ and writes A4 backgrounds to
assets/templates/. Rerunnable: the originals are kept so a change of mind about
cropping or quality is one command, not a re-download.

Three things happen to every file:

* **Centre-cropped to A4.** The supplied art comes in seven different aspect
  ratios; the app has exactly one page shape (D18). Cropping is centred, which
  is why border art must not have critical detail hard against an edge.
* **Upscaled to 1654x2339** (A4 at 200 dpi). The originals are ~600-736px wide,
  which is about 63 dpi on an A4 page — visibly soft on screen and poor from a
  print shop. Upscaling adds no detail, but Lanczos on high-contrast linework
  degrades far more gracefully than leaving each renderer to interpolate with
  whatever filter it happens to use.
* **Re-encoded as JPEG at quality 88**, which for flat linework on white is
  indistinguishable from the source and a fraction of a PNG.
"""

import os

from PIL import Image

SRC = 'tool/template-originals'
OUT = 'assets/templates'

# A4 at 200 dpi.
TARGET_W, TARGET_H = 1654, 2339
TARGET_RATIO = TARGET_W / TARGET_H

# Source file -> shipped template id. The ids are stable and stored on every
# profile that uses them, so renaming one orphans people's biodatas.
#
# Four supplied files are deliberately absent:
#   download (1).jpg   a photograph of a physical picture frame, mat and all
#   download (12).jpg  a mockup: a white page floating on a coloured backdrop
#   download (6).jpg   the same, and 16:9 besides
#   download (9).jpg   tiled stock-preview watermarks across the blank centre
TEMPLATES = {
    # Classic
    'Soft digital.jpg': 'filigree',
    'Vektorrahmen schwarz auf weißem Hintergrund _ Premium Vektor.jpg':
        'flourish',
    'IMGBIN_com - Download Transparent PNG Images, For Free.jpg': 'bold-frame',
    # Geometric
    'download (11).jpg': 'deco',
    'download (10).jpg': 'deco-light',
    'download (7).jpg': 'navy-key',
    # Botanical
    'Green Outline Flower A4 Stationery Paper Document.jpg': 'green-flower',
    'download (13).jpg': 'leaf-sprig',
    'download (4).jpg': 'olive',
    # Minimal
    'download.jpg': 'navy-wedge',
    'download (3).jpg': 'thin-rule',
    'download (5).jpg': 'peach',
    'download (2).jpg': 'paper',
}


def crop_to_a4(image):
    """Centre-crops to the A4 ratio, taking from whichever axis is too long."""
    width, height = image.size
    if width / height > TARGET_RATIO:
        # Too wide: take from the sides.
        new_width = round(height * TARGET_RATIO)
        left = (width - new_width) // 2
        return image.crop((left, 0, left + new_width, height))

    # Too tall: take from top and bottom.
    new_height = round(width / TARGET_RATIO)
    top = (height - new_height) // 2
    return image.crop((0, top, width, top + new_height))


def main():
    os.makedirs(OUT, exist_ok=True)
    missing = [n for n in TEMPLATES if not os.path.exists(os.path.join(SRC, n))]
    if missing:
        raise SystemExit('missing originals: %s' % missing)

    total = 0
    for name, template_id in sorted(TEMPLATES.items(), key=lambda kv: kv[1]):
        source = Image.open(os.path.join(SRC, name)).convert('RGB')
        prepared = crop_to_a4(source).resize(
            (TARGET_W, TARGET_H), Image.LANCZOS
        )
        path = os.path.join(OUT, '%s.jpg' % template_id)
        prepared.save(path, 'JPEG', quality=88, optimize=True)

        kb = os.path.getsize(path) // 1024
        total += kb
        print('%-14s %-9s %sx%s -> %s KB' % (
            template_id, '%dx%d' % source.size, TARGET_W, TARGET_H, kb))

    print('%d templates, %d KB total' % (len(TEMPLATES), total))


if __name__ == '__main__':
    main()
