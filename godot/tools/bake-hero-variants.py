#!/usr/bin/env python3
"""Bake the shop's garment palettes into hero sprite variants.

The web build swaps three palette slots (r/y/w) while drawing. Godot renders the
PNG as-is, so the same swap is baked into one file per hero+garment instead.

    python3 tools/bake-hero-variants.py
"""
import os
from PIL import Image

BASE = {
    "boy": {"r": "#b23a2e", "y": "#e0a72c", "w": "#e8dcc0"},
    "girl": {"r": "#8e2f4a", "y": "#e0a72c", "w": "#f2e8d4"},
}

# Mirrors Rules.GARMENT_PALETTES. garment-bahag has no palette: it uses the base art.
GARMENTS = {
    "tapis": {"r": "#3f6b9e", "y": "#8fc6d8", "w": "#dbeaf7"},
    "blank": {"r": "#8a5c3c", "y": "#b8871c", "w": "#d9c9a8"},
    "crown": {"r": "#5f3f8e", "y": "#f2c14e", "w": "#efe3ff"},
}

HERE = os.path.dirname(os.path.abspath(__file__))
SPRITES = os.path.join(os.path.dirname(HERE), "assets", "sprites")


def hex_to_rgb(value):
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def bake(hero, garment, palette):
    src = os.path.join(SPRITES, f"{hero}.png")
    image = Image.open(src).convert("RGBA")
    pixels = image.load()
    base = {k: hex_to_rgb(v) for k, v in BASE[hero].items()}
    target = {k: hex_to_rgb(v) for k, v in palette.items()}
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue
            rgb = (r, g, b)
            for slot, source_rgb in base.items():
                if rgb == source_rgb and slot in target:
                    nr, ng, nb = target[slot]
                    pixels[x, y] = (nr, ng, nb, a)
                    break
    out = os.path.join(SPRITES, f"hero-{hero}-{garment}.png")
    image.save(out)
    print("wrote", os.path.relpath(out))


for hero in BASE:
    for garment, palette in GARMENTS.items():
        bake(hero, garment, palette)
