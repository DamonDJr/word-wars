#!/usr/bin/env python3
"""Pack the BloqBot frame folders into the sprite sheets the game draws from.

    python3 tools/build_emotes.py

Reads `baseEmotes/BloqBot/<Set>/*.png` and writes one sheet per emote into
`emotes/`. Source frames are 512x512 (Love is 256) with the character floating
in a fixed canvas -- it drifts and scales *within* the frame, so each frame is
scaled whole rather than cropped to its own content. Cropping per frame would
throw away the motion and leave a character that jitters in place.

## Why sheets and not 60 loose files

Sixty 512x512 textures is 60 MB of VRAM for stickers that are drawn at 78 px.
At a 160 px cell the whole set is 6 MB, which is less than the seven 512x512
originals it replaces, and it is one file per emote rather than one per frame.

## The two-pixel gutter

Each frame sits in a 160 px cell with a 2 px transparent margin, and the game
draws the inner 156 px. Bilinear filtering at the edge of a region reaches a
texel past it, so without the gap a frame would smear its neighbour's shoulder
down its own side -- visible only in motion, and only on a device.

RGB is dilated into the transparent pixels afterwards. The source has RGB 0 at
alpha 0, and scaling straight alpha would drag that black into every edge as a
dark fringe. Done here rather than left to the importer's `fix_alpha_border`,
so the file on disk is right whatever the import settings say.
"""

import os
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "baseEmotes" / "BloqBot"
DST = ROOT / "emotes"

CELL = 160
GUTTER = 2
COLS = 6

# Source folder -> output name. The output names are what `game.gd` names in
# EMOTE_ANIM; changing one means changing both.
SETS = {
    "BloqBotExcited": "bot_excited",
    "BloqBotCry": "bot_cry",
    "BloqBotShocked": "bot_shocked",
    "BloqBotMad": "bot_mad",
    "BloqBotLove": "bot_love",
    "BloqBotHype": "bot_hype",
    "BloqBotDead": "bot_dead",
}


# BloqBot's own linework, and the floor every drawn pixel is held to.
#
# `game.gd` uses #000000 precisely nowhere — the whole UI bottoms out at
# #0b1020 — so pure black on screen is only ever these files, and against a
# panel that dark it reads as a hole punched through it rather than as ink. The
# old white character was re-levelled by hand for the same reason; doing it here
# means a re-export from the drawing tool cannot quietly undo it.
#
# Only Mad actually trips this, with the black puffs over its head. Everything
# else bottoms out at 29 already, so the threshold sits well below anything the
# art draws on purpose and well above true black.
INK = np.array([0x0b, 0x12, 0x20], dtype=np.float32) / 255.0
INK_FLOOR = 16.0 / 255.0


def scaled(path, size):
    """One frame at `size`, resized through premultiplied alpha."""
    im = np.asarray(Image.open(path).convert("RGBA"), dtype=np.float32) / 255.0
    # Lifted before the resize, not after, so the anti-aliased edge blends
    # towards the ink colour rather than towards a black the art no longer has.
    drawn = im[..., 3] > 0.0
    black = drawn & (im[..., :3].max(axis=2) <= INK_FLOOR)
    im[black, 0:3] = INK
    a = im[..., 3:4]
    pre = np.concatenate([im[..., :3] * a, a], axis=2)
    small = np.asarray(
        Image.fromarray((pre * 255.0 + 0.5).astype(np.uint8), "RGBA").resize(
            (size, size), Image.LANCZOS
        ),
        dtype=np.float32,
    ) / 255.0
    out_a = small[..., 3:4]
    # Back to straight alpha. Where nothing landed there is no colour to
    # recover, so those pixels are left to the dilate below.
    rgb = np.divide(small[..., :3], out_a, out=np.zeros_like(small[..., :3]),
                    where=out_a > 1e-4)
    rgb = np.clip(rgb, 0.0, 1.0)
    # And lifted a second time, because Lanczos has negative lobes: a dark
    # pixel beside a bright one rings *below* the darkest input and clamps at
    # zero. That is where the handful of black pixels in every sheet came from
    # — the source has nothing under 29, and the resize was manufacturing them.
    out = np.concatenate([rgb, out_a], axis=2)
    rung = (out[..., 3] > 1e-4) & (out[..., :3].max(axis=2) <= INK_FLOOR)
    out[rung, 0:3] = INK
    return out


def dilate(sheet, passes=4):
    """Push edge colour outwards into transparency, in place."""
    rgb = sheet[..., :3]
    a = sheet[..., 3]
    for _ in range(passes):
        solid = a > 1e-4
        if solid.all():
            break
        # Four-neighbour average of whichever neighbours have colour.
        acc = np.zeros_like(rgb)
        cnt = np.zeros_like(a)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n_rgb = np.roll(np.roll(rgb, dy, axis=0), dx, axis=1)
            n_ok = np.roll(np.roll(solid, dy, axis=0), dx, axis=1)
            acc += n_rgb * n_ok[..., None]
            cnt += n_ok
        fill = (~solid) & (cnt > 0)
        rgb[fill] = acc[fill] / cnt[fill][..., None]
        # Marked as having colour for the next pass, without gaining opacity.
        a = np.where(fill, 1e-3, a)
    return sheet


def build(folder, name):
    frames = sorted((SRC / folder).glob("*.png"))
    if not frames:
        raise SystemExit("no frames in %s" % (SRC / folder))
    rows = (len(frames) + COLS - 1) // COLS
    sheet = np.zeros((rows * CELL, COLS * CELL, 4), dtype=np.float32)
    inner = CELL - GUTTER * 2
    for i, f in enumerate(frames):
        y = (i // COLS) * CELL + GUTTER
        x = (i % COLS) * CELL + GUTTER
        sheet[y:y + inner, x:x + inner] = scaled(f, inner)
    dilate(sheet)
    # The dilate marks filled pixels with a token alpha so the next pass can
    # spread from them; nothing on screen should be 0.4% opaque.
    sheet[..., 3] = np.where(sheet[..., 3] < 0.004, 0.0, sheet[..., 3])
    out = DST / ("%s.png" % name)
    Image.fromarray((sheet * 255.0 + 0.5).astype(np.uint8), "RGBA").save(out)
    print("%-12s %2d frames  %dx%d  %d KB"
          % (name, len(frames), COLS * CELL, rows * CELL,
             out.stat().st_size // 1024))
    return len(frames), rows


def main():
    if not SRC.is_dir():
        raise SystemExit("no source art at %s" % SRC)
    print("cell %d  gutter %d  cols %d" % (CELL, GUTTER, COLS))
    for folder, name in SETS.items():
        count, rows = build(folder, name)
        print("%-12s -> {\"frames\": %d, \"rows\": %d}" % ("", count, rows))


if __name__ == "__main__":
    sys.exit(main())
