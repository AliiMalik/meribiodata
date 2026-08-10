# -*- coding: utf-8 -*-
"""Builds the two Play Store graphics from the app icon artwork.

Play rejects a listing icon with an alpha channel, and it rejects a feature
graphic that is not exactly 1024x500. Both are easy to get wrong by hand and
neither is worth redrawing, so they are derived here from the same source the
launcher icon uses.

    python tool/make_store_assets.py

Writes into docs/brand/store/, which is not shipped in the app.
"""

import os

from PIL import Image, ImageFilter

SOURCE = 'assets/images/icon.png'
OUT = 'docs/brand/store'

# Sampled from the source rather than typed in, so the feature graphic cannot
# drift away from the icon's own green if the artwork is ever replaced.
def background_colour(image):
    """The average colour of a top-left patch.

    Deliberately not "the most common pixel": the green in this artwork is
    faintly textured, so no single green value repeats, while the silhouette is
    perfectly flat. Counting pixels therefore elects black — the one colour the
    background certainly is not. A corner is background by construction.
    """
    rgb = image.convert('RGB')
    side = max(1, rgb.width // 20)
    patch = rgb.crop((0, 0, side, side))
    pixels = list(patch.getdata())
    channels = zip(*pixels)
    return tuple(round(sum(c) / len(pixels)) for c in channels)


def flatten(image, colour):
    """Drops the alpha channel onto a solid background.

    Play's listing icon must be a 32-bit PNG with no transparency; an icon with
    alpha is rejected outright rather than composited onto something sensible.
    """
    flat = Image.new('RGB', image.size, colour)
    flat.paste(image, mask=image.split()[3] if image.mode == 'RGBA' else None)
    return flat


def main():
    os.makedirs(OUT, exist_ok=True)
    source = Image.open(SOURCE)
    green = background_colour(source)
    print('sampled background:', green)

    # The 512 listing icon is written by make_icon.py, from the same master.
    # Two tools writing one file is how they drift apart.

    # 1024x500. The artwork is square and the canvas is wide, so the icon is
    # placed rather than stretched — Play crops this graphic differently across
    # surfaces, and anything important near an edge gets cut.
    # A square mark cannot fill a 1024x500 canvas: scaling to fill crops the
    # heads off and loses the wordmark entirely, and pasting it onto a flat
    # green rectangle leaves a visible seam, because the artwork's green is
    # faintly textured and no sampled flat colour matches it.
    #
    # So the backdrop is the artwork itself — scaled to fill, then blurred hard.
    # It carries the same texture and the same green by construction, so there
    # is nothing to mismatch. The whole mark then sits sharp on top of it.
    flat = flatten(source, green)

    fill = max(1024 / flat.width, 500 / flat.height)
    backdrop = flat.resize(
        (round(flat.width * fill), round(flat.height * fill)), Image.LANCZOS
    )
    left = (backdrop.width - 1024) // 2
    top = (backdrop.height - 500) // 2
    feature = backdrop.crop((left, top, left + 1024, top + 500)).filter(
        ImageFilter.GaussianBlur(60)
    )

    mark = flat.resize((500, 500), Image.LANCZOS)
    feature.paste(mark, ((1024 - 500) // 2, 0))
    feature_path = os.path.join(OUT, 'play-feature-1024x500.png')
    feature.save(feature_path, 'PNG')
    print('wrote', feature_path, feature.size)


if __name__ == '__main__':
    main()
