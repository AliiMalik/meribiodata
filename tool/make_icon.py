# -*- coding: utf-8 -*-
"""Builds every launcher icon size from the master artwork.

Source: assets/images/icon.png — a white Islamic interlace border with the app
name inside it, on the brand green.

Checked in and re-runnable so the master art stays the single source of truth.
Replacing the icon later means dropping in a new PNG and running this again,
not re-cutting nine files by hand.

**It splits the art into adaptive layers.** Android 8+ — every device this app
supports, minSdk 26 — composites a background and a foreground and then applies
whatever mask the launcher chooses, clipping anything outside the inner 66% of
the canvas.

**The whole design stays visible**, at the owner's request. Rather than crop the
border off, the entire white artwork is scaled down to sit inside the safe zone,
so every launcher mask shows the complete frame and wording.

**The white is lifted onto a transparent layer** rather than pasting the square
artwork over a green square. Compositing white-on-nothing over flat green cannot
show a seam; pasting one green over another can, and does, because no sampled
flat colour ever quite matches the source.

The wording is legible on the Play Store asset, which is never masked, and is a
smudge at 48dp on a launcher. That is inherent to putting three lines of text in
an app icon and was accepted knowingly.
"""

import os

from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), '..')
SOURCE = os.path.join(ROOT, 'assets', 'images', 'icon.png')
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
# A circular mask shows a 72dp disc of the 108dp canvas, so 0.667 is the ceiling
# for anything that must survive every launcher. The artwork is a square frame,
# and a square inscribed in that disc is narrower still — hence 0.62 rather than
# sitting on the limit.
SAFE_FRACTION = 0.62

# Measured from the artwork, not guessed. The green background sits at a
# luminance around 100 and the white linework at 250+, so the ramp between 170
# and 230 lifts the white cleanly and leaves the anti-aliased edges soft.
SOLID, FADE = 230, 170


def brand_green(image):
    """The background colour, taken from the art rather than hardcoded.

    A corner, because the corner is background by construction. Counting the
    most common pixel would elect white here, which covers 27% of the canvas.
    """
    rgb = image.convert('RGB')
    side = max(1, rgb.width // 25)
    pixels = list(rgb.crop((0, 0, side, side)).getdata())
    return tuple(round(sum(c) / len(pixels)) for c in zip(*pixels))


def linework(image):
    """Lifts the white border and wording onto a transparent-backed image."""
    rgb = image.convert('RGB')
    lum = rgb.convert('L')
    alpha = lum.point(
        lambda v: 0 if v <= FADE
        else 255 if v >= SOLID
        else round(255 * (v - FADE) / (SOLID - FADE))
    )

    white = Image.new('RGBA', rgb.size, (255, 255, 255, 0))
    white.putalpha(alpha)
    return white.crop(white.getbbox() or (0, 0, rgb.width, rgb.height))


def foreground(art, size):
    """The adaptive foreground: the whole design, inside the safe zone."""
    canvas = Image.new('RGBA', (size, size), (0, 0, 0, 0))

    limit = size * SAFE_FRACTION
    scale = min(limit / art.width, limit / art.height)
    scaled = art.resize(
        (max(1, round(art.width * scale)), max(1, round(art.height * scale))),
        Image.LANCZOS,
    )
    canvas.paste(
        scaled,
        ((size - scaled.width) // 2, (size - scaled.height) // 2),
        scaled,
    )
    return canvas


def background(colour, size):
    return Image.new('RGB', (size, size), colour)


def legacy(art, colour, size):
    """The square/round icon for launchers that ignore adaptive layers."""
    icon = background(colour, size).convert('RGBA')
    icon.alpha_composite(foreground(art, size))
    return icon.convert('RGB')


def main():
    master = Image.open(SOURCE)
    green = brand_green(master)
    art = linework(master)
    print('brand green %s, linework %dx%d' % (green, art.width, art.height))

    for density, px in DENSITIES:
        out = os.path.join(RES, 'mipmap-' + density)
        os.makedirs(out, exist_ok=True)

        background(green, px).save(
            os.path.join(out, 'ic_launcher_background.png'))
        foreground(art, px).save(
            os.path.join(out, 'ic_launcher_foreground.png'))
        # Pre-Oreo launchers, and anything asking for the round variant, get a
        # flattened copy. minSdk is 26 so these are a fallback, not the norm.
        flat = legacy(art, green, px)
        flat.save(os.path.join(out, 'ic_launcher.png'))
        flat.save(os.path.join(out, 'ic_launcher_round.png'))
        print('  mipmap-%-8s %dpx' % (density, px))

    os.makedirs(BRAND, exist_ok=True)
    # The Play listing icon is never masked, so it is the artwork whole, at the
    # size Play demands, with no alpha — an icon with transparency is rejected.
    master.convert('RGB').resize((512, 512), Image.LANCZOS).save(
        os.path.join(BRAND, 'store', 'play-icon-512.png'))
    print('  play-icon-512.png')


if __name__ == '__main__':
    main()
