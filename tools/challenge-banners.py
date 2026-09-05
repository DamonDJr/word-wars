from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os, math, random

S = os.environ['SCRATCH']
W, H = 3840, 2160
GLITCH = "fonts/RubikGlitch-Regular.ttf"
SANS_B = "/usr/share/fonts/TTF/DejaVuSans-Bold.ttf"
SANS   = "/usr/share/fonts/TTF/DejaVuSans.ttf"

# Straight out of the game: THEMES/midnight, the boot splash, and TIER_COLORS.
BG_TOP, BG_BOT = (1, 6, 26), (20, 26, 54)
TIERS = ["#5390d9", "#48bfe3", "#64dfdf", "#f9c74f", "#f8961e", "#f94144"]
INK, MUTE = (230, 236, 255), (125, 136, 173)


def hx(c):
    c = c.lstrip('#')
    return tuple(int(c[i:i+2], 16) for i in (0, 2, 4))


def ground(accent):
    im = Image.new('RGB', (W, H), BG_TOP)
    d = ImageDraw.Draw(im)
    for y in range(H):
        t = y / H
        d.line([(0, y), (W, y)], fill=tuple(
            int(BG_TOP[i] + (BG_BOT[i] - BG_TOP[i]) * t) for i in range(3)))
    # The bloom the playfield draws behind the board, same trick: stacked
    # discs at very low alpha so it works without a shader.
    glow = Image.new('RGB', (W, H), (0, 0, 0))
    g = ImageDraw.Draw(glow)
    cx, cy = int(W * 0.30), int(H * 0.52)
    for i in range(9):
        f = i / 8.0
        r = int(W * (0.10 + f * 0.42))
        v = int(26 * (1.0 - f))
        g.ellipse([cx - r, cy - r, cx + r, cy + r],
                  fill=tuple(int(c * v / 255) for c in accent))
    glow = glow.filter(ImageFilter.GaussianBlur(90))
    return Image.blend(im, Image.blend(im, glow, 0.0), 0.0) if False else \
        Image.fromarray(__import__('numpy').clip(
            __import__('numpy').asarray(im, dtype=int)
            + __import__('numpy').asarray(glow, dtype=int), 0, 255).astype('uint8'))


def decor(im, seed):
    # The drifting blocks behind every menu. Low contrast on purpose.
    rnd = random.Random(seed)
    lay = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    for _ in range(26):
        s = rnd.randint(90, 300)
        x, y = rnd.randint(-100, W), rnd.randint(-100, H)
        col = hx(rnd.choice(TIERS))
        a = rnd.randint(8, 22)
        tile = Image.new('RGBA', (s, s), (0, 0, 0, 0))
        ImageDraw.Draw(tile).rounded_rectangle([0, 0, s, s], radius=int(s * 0.18),
                                               fill=col + (a,))
        lay.alpha_composite(tile.rotate(rnd.randint(-28, 28), expand=True), (x, y))
    return Image.alpha_composite(im.convert('RGBA'), lay).convert('RGB')


def block(im, box, col, label, font):
    """One playfield block: filled tile, lighter border, a stamp on it."""
    x0, y0, x1, y1 = box
    s = min(x1 - x0, y1 - y0)
    tile = Image.new('RGBA', (x1 - x0 + 60, y1 - y0 + 60), (0, 0, 0, 0))
    td = ImageDraw.Draw(tile)
    # Drop shadow first, the way _panel does.
    td.rounded_rectangle([34, 40, x1 - x0 + 34, y1 - y0 + 44],
                         radius=int(s * 0.17), fill=(0, 0, 0, 110))
    tile = tile.filter(ImageFilter.GaussianBlur(14))
    td = ImageDraw.Draw(tile)
    td.rounded_rectangle([30, 30, x1 - x0 + 30, y1 - y0 + 30],
                         radius=int(s * 0.17), fill=col + (255,),
                         outline=tuple(min(255, int(c * 1.35)) for c in col) + (255,),
                         width=max(3, s // 42))
    if label:
        w = td.textlength(label, font=font)
        a = font.getbbox(label)
        td.text(((x1 - x0 + 60 - w) / 2, 30 + (y1 - y0 - (a[3] - a[1])) / 2 - a[1]),
                label, font=font, fill=(11, 16, 32, 255))
    im.paste(tile, (x0 - 30, y0 - 30), tile)


def fit(d, text, font_path, start, max_w, floor=40):
    """Shrink until it fits. A banner that runs off its own edge is worse
    than one set a little smaller."""
    size = start
    while size > floor:
        f = ImageFont.truetype(font_path, size)
        if d.textlength(text, font=f) <= max_w:
            return f
        size -= 4
    return ImageFont.truetype(font_path, floor)


def banner(name, word, stamp, sub, accent_hex, tiers, out):
    accent = hx(accent_hex)
    im = ground(accent)
    im = decor(im, sum(ord(c) for c in name))
    d = ImageDraw.Draw(im)

    SAFE = int(W * 0.80)          # keep clear of any crop Game Center applies
    f_word = fit(d, word, GLITCH, 340, SAFE * 0.58)
    f_stamp = ImageFont.truetype(SANS_B, 150)
    f_sub = fit(d, sub, SANS, 96, SAFE * 0.62)
    f_mark = ImageFont.truetype(GLITCH, 72)

    # Measure the whole [blocks + word] group, then centre it as one object.
    # Laying the two out against fixed fractions of the width is what pushed
    # the first draft's sub line off the right-hand edge.
    n = len(stamp)
    bs, gap, split = 300, 34, 150
    blocks_w = n * bs + (n - 1) * gap
    wb = f_word.getbbox(word)
    word_w = int(d.textlength(word, font=f_word))
    group_w = blocks_w + split + word_w
    gx = int((W - group_w) // 2)
    mid = int(H * 0.47)

    by = mid - bs // 2
    for i, ch in enumerate(stamp):
        block(im, (gx + i * (bs + gap), by, gx + i * (bs + gap) + bs, by + bs),
              hx(tiers[i % len(tiers)]), ch, f_stamp)

    tx = gx + blocks_w + split
    ty = int(mid - (wb[3] + wb[1]) // 2)
    d.text((tx + 8, ty + 10), word, font=f_word, fill=(0, 0, 0))
    d.text((tx, ty), word, font=f_word, fill=accent)

    ry = ty + wb[3] + 70
    d.rectangle([tx, ry, tx + word_w, ry + 8], fill=accent)

    # Sub centred under the group rather than under the word, so the block row
    # is part of the composition instead of hanging off the side of it.
    sub_w = int(d.textlength(sub, font=f_sub))
    d.text(((W - sub_w) / 2, ry + 74), sub, font=f_sub, fill=MUTE)

    d.text((150, H - 190), "WORD WARS", font=f_mark, fill=(90, 102, 140))
    im.save(out, quality=95)
    return out


os.makedirs(S + "/challenge", exist_ok=True)
print(banner("daily", "DAILY", "DAI", "One run. The same board for everyone.",
             "#ffd166", ["#f9c74f", "#f8961e", "#5390d9"], S + "/challenge/challenge-daily.png"))
print(banner("survival", "SURVIVAL", "SUR", "No clock. Last as long as you can.",
             "#f94144", ["#f94144", "#f8961e", "#64dfdf"], S + "/challenge/challenge-survival.png"))
