# -*- coding: utf-8 -*-
"""Builds every launcher icon size from the master artwork.

Source: assets/images/meribiodata.png — a couple in shalwar kameez and dupatta,
black on the brand green, with the wordmark beneath.

Checked in and re-runnable so the master art stays the single source of truth.
Replacing the icon later means dropping in a new PNG and running this again,
not re-cutting nine files by hand.

Two things this does that a plain resize would not:

**It splits the art into adaptive layers.** Android 8+ — every device this app
supports, minSdk 26 — composites a background and a foreground and then applies
whatever mask the launcher chooses, clipping anything outside the inner 66% of
the canvas. So the foreground gets the silhouette alone, scaled to survive that
crop, and the background gets flat brand green.

**It drops the wordmark from the launcher icon.** The mask would eat it, and
text is illegible at 48dp regardless. The wordmark survives on the Play Store
asset, which is never masked.
"""

import os

from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(__file__), '..')
SOURCE = os.path.join(ROOT, 'assets', 'images', 'meribiodata.png')
RES = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res')
BRAND = os.path.join(ROOT, 'docs', 'brand')

# Densities Android wants, at the 108dp adaptive canvas size.
DENSITIES = [
    ('mdpi', 108),
    ('hdpi', 162),
    ('xhdpi', 216),
    ('xxhdpi', 324),
    ('xxxhdpi', 432),
]

# Share of the 108dp canvas the artwork may occupy.
#
# A circular mask shows a 72dp disc of the 108dp canvas, so 0.667 is the
# absolute ceiling. The figures are taller than they are wide, and it is their
# *height* that would clip first, so this sits just under: 0.64 x 108 = 69dp.
SAFE_FRACTION = 0.64


def brand_green(img):
    """The background colour, taken from the art rather than hardcoded.

    Sampled around the border and averaged, so a subtle vignette in the source
    does not become a visible seam against the flat layer.
    """
    w, h = img.size
    edge = []
    for i in range(0, w, 7):
        edge.append(img.getpixel((i, 2)))
        edge.append(img.getpixel((i, h - 3)))
    for i in range(0, h, 7):
        edge.append(img.getpixel((2, i)))
        edge.append(img.getpixel((w - 3, i)))
    n = len(edge)
    return tuple(round(sum(c[i] for c in edge) / n) for i in range(3))


def silhouette(img):
    """Lifts the figures off the background as a transparent-backed image.

    Keyed on darkness rather than an exact colour match. Measured on the master
    art, the max-channel histogram is strongly bimodal: the silhouette sits at
    0-20, the green background at 93-129, and the white wordmark above 250. The
    thresholds below are placed in that empty middle, with five units of margin
    under the darkest background pixel found (93).

    Getting this wrong is not subtle — an earlier ceiling of 110 sat *above* the
    green and selected the entire image.

    The wordmark is white, so it falls out for free.
    """
    solid, fade = 25, 88
    w, h = img.size
    px = img.convert('RGB').load()

    out = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    op = out.load()

    for y in range(h):
        for x in range(w):
            peak = max(px[x, y])
            if peak < solid:
                op[x, y] = (12, 12, 12, 255)
            elif peak < fade:
                # The anti-aliased rim. Fading it rather than cutting at a hard
                # threshold is what keeps edges smooth after downscaling.
                op[x, y] = (12, 12, 12, round(255 * (fade - peak) / (fade - solid)))

    return out.crop(out.getbbox())


def foreground(figures, size):
    """The adaptive foreground layer: figures centred inside the safe zone."""
    canvas = Image.new('RGBA', (size, size), (0, 0, 0, 0))

    limit = size * SAFE_FRACTION
    scale = min(limit / figures.width, limit / figures.height)
    art = figures.resize(
        (max(1, round(figures.width * scale)),
         max(1, round(figures.height * scale))),
        Image.LANCZOS,
    )

    canvas.paste(art, ((size - art.width) // 2, (size - art.height) // 2), art)
    return canvas


def rounded(img, radius_ratio=0.22):
    size = img.size[0]
    mask = Image.new('L', (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, size - 1, size - 1], radius=round(size * radius_ratio), fill=255)
    out = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    return out


def circle(img):
    size = img.size[0]
    mask = Image.new('L', (size, size), 0)
    ImageDraw.Draw(mask).ellipse([0, 0, size - 1, size - 1], fill=255)
    out = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    return out


def main():
    master = Image.open(SOURCE).convert('RGB')
    green = brand_green(master)
    figures = silhouette(master)
    print('brand green {}, figures {}x{}'.format(
        green, figures.width, figures.height))

    os.makedirs(BRAND, exist_ok=True)

    for density, px in DENSITIES:
        out = os.path.join(RES, 'mipmap-' + density)
        os.makedirs(out, exist_ok=True)

        Image.new('RGB', (px, px), green).save(
            os.path.join(out, 'ic_launcher_background.png'))
        foreground(figures, px).save(
            os.path.join(out, 'ic_launcher_foreground.png'))

        # Legacy layers, for launchers that ignore adaptive icons. The whole
        # composition, wordmark included, since nothing masks these.
        legacy = master.resize((px, px), Image.LANCZOS)
        rounded(legacy).save(os.path.join(out, 'ic_launcher.png'))
        circle(legacy).save(os.path.join(out, 'ic_launcher_round.png'))

    master.resize((512, 512), Image.LANCZOS).save(
        os.path.join(BRAND, 'play-store-icon-512.png'))

    # What the home screen actually shows, for review.
    preview = Image.new('RGB', (432, 432), green)
    layer = foreground(figures, 432)
    preview.paste(layer, (0, 0), layer)
    circle(preview).save(os.path.join(BRAND, 'launcher-preview-round.png'))

    print('icons written')


if __name__ == '__main__':
    main()
