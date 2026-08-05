# -*- coding: utf-8 -*-
"""Draws the launcher icon.

Checked in rather than run once and forgotten, because the icon is geometry
rather than a painting: every size is generated from the same parametric
description, so a tweak means editing three numbers instead of re-cutting nine
PNGs by hand.

Design (author's brief): a black silhouette of a woman in a dupatta on the
brand green, with the wordmark alongside.

The wordmark only appears on the Play Store asset. Android 8+ — which is every
device this app supports, minSdk 26 — masks the launcher icon to a circle or a
squircle chosen by the launcher, and clips anything outside the inner 66% of
the canvas. Text placed at the sides is the first thing that mask eats, so on
the phone the icon is the silhouette alone, which is what reads at 48dp anyway.
"""

import math
import os
from PIL import Image, ImageDraw, ImageFont

GREEN = (22, 101, 52)        # AppColors.primaryDark
GREEN_DEEP = (13, 74, 38)    # a touch darker for the radial falloff
BLACK = (10, 10, 10)

OUT = os.path.join(os.path.dirname(__file__), '..', 'android', 'app', 'src',
                   'main', 'res')
BRAND = os.path.join(os.path.dirname(__file__), '..', 'docs', 'brand')


def background(size):
    """Brand green with a soft vignette, so the icon is not a flat slab."""
    img = Image.new('RGB', (size, size), GREEN)
    px = img.load()
    centre = size / 2
    longest = centre * 1.45
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - centre, y - centre * 0.92) / longest
            t = min(1.0, max(0.0, d)) ** 1.6
            px[x, y] = (
                round(GREEN[0] + (GREEN_DEEP[0] - GREEN[0]) * t),
                round(GREEN[1] + (GREEN_DEEP[1] - GREEN[1]) * t),
                round(GREEN[2] + (GREEN_DEEP[2] - GREEN[2]) * t),
            )
    return img


def _bezier(p0, p1, p2, p3, steps):
    """Samples one cubic segment, excluding its first point."""
    out = []
    for i in range(1, steps + 1):
        t = i / steps
        u = 1 - t
        x = (u ** 3 * p0[0] + 3 * u * u * t * p1[0]
             + 3 * u * t * t * p2[0] + t ** 3 * p3[0])
        y = (u ** 3 * p0[1] + 3 * u * u * t * p1[1]
             + 3 * u * t * t * p2[1] + t ** 3 * p3[1])
        out.append((x, y))
    return out


# The right-hand half of the outline, in head-units: x from the centre line, y
# from the crown. Mirrored for the left, so the figure is exactly symmetrical.
#
# It is one continuous path from the crown to below the frame — crown, veil,
# jaw, drape, shoulder, body. An earlier version drew the shoulders as a
# separate arc and unioned the two shapes, which left the drape poking out past
# the shoulder line as a pair of little wings. A single closed path cannot have
# a seam.
#
# The shape lives or dies on the third segment, where the outline comes *in* at
# the jaw before falling away. Without that the silhouette reads as loose long
# hair; with it, the eye sees fabric framing a face.
_OUTLINE = [
    # (control 1, control 2, end point)
    ((0.37, 0.005), (0.635, 0.17), (0.655, 0.46)),  # crown
    ((0.665, 0.64), (0.675, 0.79), (0.655, 0.97)),  # side of the veil
    ((0.64, 1.10), (0.605, 1.18), (0.575, 1.28)),   # in at the jaw
    ((0.56, 1.46), (0.74, 1.63), (0.98, 1.80)),     # the drape falls away
    ((1.28, 1.99), (1.60, 2.08), (1.82, 2.30)),     # over the shoulder
    ((1.90, 2.40), (1.92, 2.60), (1.92, 3.60)),     # down past the frame
]


def silhouette(size, scale=1.0, drop=0.0):
    """Head-and-shoulders in a dupatta, as one filled shape on transparency.

    Drawn at 4x and downsampled: at 48dp the jaw curve is only a few pixels of
    difference and aliasing eats it.
    """
    ss = 4
    w = size * ss
    img = Image.new('RGBA', (w, w), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    cx = w / 2
    unit = w * 0.262 * scale
    top = w * (0.135 + drop)

    right = [(0.0, 0.0)]
    for c1, c2, end in _OUTLINE:
        right += _bezier(right[-1], c1, c2, end, 44)

    def place(points, mirror):
        sign = -1 if mirror else 1
        return [(cx + sign * x * unit, top + y * unit) for x, y in points]

    # Down the right side, then back up the left.
    d.polygon(place(right, False) + place(right[::-1], True),
              fill=BLACK + (255,))

    return img.resize((size, size), Image.LANCZOS)


def font(size):
    for name in ('seguisb.ttf', 'segoeuib.ttf', 'arialbd.ttf', 'Arial Bold.ttf'):
        path = os.path.join(r'C:\Windows\Fonts', name)
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def compose(size, with_wordmark=False, scale=1.0, drop=0.0):
    img = background(size).convert('RGBA')
    img.alpha_composite(silhouette(size, scale=scale, drop=drop))

    if with_wordmark:
        d = ImageDraw.Draw(img)
        f = font(round(size * 0.088))
        for text, y in (('MERI', 0.795), ('BIODATA', 0.875)):
            box = d.textbbox((0, 0), text, font=f)
            d.text(((size - (box[2] - box[0])) / 2, size * y), text,
                   font=f, fill=(255, 255, 255, 235))
    return img.convert('RGB')


def rounded(img, radius_ratio=0.22):
    """Legacy square icon, for launchers that do not use adaptive icons."""
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
    os.makedirs(BRAND, exist_ok=True)

    # Adaptive icon layers. Android draws these at 108dp and shows the middle
    # 72dp, so the artwork is scaled down and the safe zone left empty.
    for density, px in (('mdpi', 108), ('hdpi', 162), ('xhdpi', 216),
                        ('xxhdpi', 324), ('xxxhdpi', 432)):
        d = os.path.join(OUT, 'mipmap-' + density)
        os.makedirs(d, exist_ok=True)

        background(px).save(os.path.join(d, 'ic_launcher_background.png'))
        # 0.62 keeps the whole silhouette inside the 66% safe zone whichever
        # mask the launcher picks.
        silhouette(px, scale=0.62, drop=0.06).save(
            os.path.join(d, 'ic_launcher_foreground.png'))

        legacy = compose(px)
        rounded(legacy).save(os.path.join(d, 'ic_launcher.png'))
        circle(legacy).save(os.path.join(d, 'ic_launcher_round.png'))

    # Play Store listing icon: 512x512, no mask, so the wordmark survives.
    compose(512, with_wordmark=True, scale=0.84, drop=-0.012).save(
        os.path.join(BRAND, 'play-store-icon-512.png'))
    # A look at what lands on the home screen, for review.
    circle(compose(432, scale=0.62, drop=0.06)).save(
        os.path.join(BRAND, 'launcher-preview-round.png'))

    print('icons written')


if __name__ == '__main__':
    main()
