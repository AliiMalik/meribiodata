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

from PIL import Image

SOURCE = 'assets/images/meribiodata.png'
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

    # 512x512, no alpha.
    icon = flatten(source, green).resize((512, 512), Image.LANCZOS)
    icon_path = os.path.join(OUT, 'play-icon-512.png')
    icon.save(icon_path, 'PNG')
    print('wrote', icon_path, icon.size)

    # 1024x500. The artwork is square and the canvas is wide, so the icon is
    # placed rather than stretched — Play crops this graphic differently across
    # surfaces, and anything important near an edge gets cut.
    feature = Image.new('RGB', (1024, 500), green)
    # Nearly full height, centred, with green either side. Play crops this
    # graphic differently across its surfaces, so the wordmark stays in the
    # middle where no crop can reach it.
    mark_height = 470
    mark = flatten(source, green).resize(
        (mark_height, mark_height), Image.LANCZOS
    )
    feature.paste(mark, ((1024 - mark_height) // 2, (500 - mark_height) // 2))
    feature_path = os.path.join(OUT, 'play-feature-1024x500.png')
    feature.save(feature_path, 'PNG')
    print('wrote', feature_path, feature.size)


if __name__ == '__main__':
    main()
