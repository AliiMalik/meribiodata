# -*- coding: utf-8 -*-
"""Turns raw device captures into Play-compliant store screenshots.

    python tool/make_screenshots.py <capture-dir> <out-dir>

Play requires an aspect ratio between 16:9 and 9:16 with each side 320-3840px,
and wants at least four at 1080px or more to be eligible for promotion. A raw
capture from a modern phone is taller than 9:16 — the Pixel emulator gives
1280x2856, a ratio of 1:2.23 — so uploading one unedited is rejected.

Two things are cropped away before the resize:

* **the status bar**, which shows an emulator clock and a VPN key icon that
  have nothing to do with the app;
* **the bottom strip**, which carries the ad banner. During testing that reads
  "Test Ad", and a store screenshot advertising Google's placeholder looks
  broken rather than honest. The banner is a real part of the app and is
  disclosed in the listing text; it just does not belong in a hero image.

What is left is centre-cropped to exactly 9:16 and resized to 1080x1920.
"""

import os
import sys

from PIL import Image

# Measured against the Pixel emulator captures at 1280x2856.
STATUS_BAR = 110
BOTTOM_STRIP = 470

TARGET = (1080, 1920)
RATIO = TARGET[0] / TARGET[1]


def prepare(image):
    """Crops the chrome, then centre-crops to 9:16 and resizes."""
    width, height = image.size
    trimmed = image.crop((0, STATUS_BAR, width, height - BOTTOM_STRIP))

    # Centre-crop whichever axis is still too long for 9:16.
    width, height = trimmed.size
    if width / height > RATIO:
        keep = round(height * RATIO)
        left = (width - keep) // 2
        trimmed = trimmed.crop((left, 0, left + keep, height))
    else:
        keep = round(width / RATIO)
        top = (height - keep) // 2
        trimmed = trimmed.crop((0, top, width, top + keep))

    return trimmed.resize(TARGET, Image.LANCZOS)


def main():
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    source, out = sys.argv[1], sys.argv[2]
    os.makedirs(out, exist_ok=True)

    names = sorted(n for n in os.listdir(source) if n.endswith('.png'))
    if not names:
        raise SystemExit('no captures in ' + source)

    for name in names:
        prepared = prepare(Image.open(os.path.join(source, name)).convert('RGB'))
        path = os.path.join(out, name)
        prepared.save(path, 'PNG', optimize=True)
        kb = os.path.getsize(path) // 1024
        print('%-28s -> %dx%d  %s KB' % (name, TARGET[0], TARGET[1], kb))

    print('%d screenshots in %s' % (len(names), out))


if __name__ == '__main__':
    main()
