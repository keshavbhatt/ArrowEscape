#!/usr/bin/env python3
"""Convert an icon (emoji, symbol glyph, or PNG) into a grid mask for a Picture
Pack. A mask is a list of row-strings using '#' for filled cells. Higher
(cols,rows) → denser, more detailed silhouettes.

  from_emoji("🐱", 20, 20)          # detailed silhouette from a color emoji
  from_glyph("★", 18, 18)           # from a font glyph
  from_png("path.png", 20, 20)      # from an image's alpha/luminance
"""
from PIL import Image, ImageDraw, ImageFont
import numpy as np, glob, os

EMOJI  = "/usr/share/fonts/noto/NotoColorEmoji.ttf"
SYMBOL = "/usr/share/fonts/TTF/DejaVuSans.ttf"

def _emoji_coverage(ch):
    font = ImageFont.truetype(EMOJI, 109)
    img = Image.new("RGBA", (180, 180), (0, 0, 0, 0))
    ImageDraw.Draw(img).text((90, 90), ch, font=font, embedded_color=True, anchor="mm")
    return img.split()[-1]                        # alpha channel as coverage

def _glyph_coverage(ch, font_path=SYMBOL):
    font = ImageFont.truetype(font_path, 220)
    img = Image.new("L", (300, 300), 0)
    ImageDraw.Draw(img).text((150, 150), ch, font=font, fill=255, anchor="mm")
    return img

def _largest_cc(m):
    rows, cols = m.shape; seen = np.zeros_like(m, bool); best = []
    for sr in range(rows):
        for sc in range(cols):
            if m[sr, sc] and not seen[sr, sc]:
                stack = [(sr, sc)]; comp = []
                seen[sr, sc] = True
                while stack:
                    r, c = stack.pop(); comp.append((r, c))
                    for dr, dc in ((1,0),(-1,0),(0,1),(0,-1)):
                        nr, nc = r+dr, c+dc
                        if 0<=nr<rows and 0<=nc<cols and m[nr,nc] and not seen[nr,nc]:
                            seen[nr,nc]=True; stack.append((nr,nc))
                if len(comp) > len(best): best = comp
    out = np.zeros_like(m)
    for r, c in best: out[r, c] = True
    return out

def to_mask(cov, cols, rows, thresh=0.42, fill=0.92, keep_largest=True):
    a = np.asarray(cov, dtype=float) / 255.0
    ys, xs = np.where(a > 0.12)
    if len(xs) == 0: return ["."*cols]*rows
    a = a[ys.min():ys.max()+1, xs.min():xs.max()+1]
    h, w = a.shape
    s = min(cols/w, rows/h) * fill
    nw, nh = max(1, round(w*s)), max(1, round(h*s))
    im = Image.fromarray((a*255).astype("uint8")).resize((nw, nh), Image.LANCZOS)
    g = np.asarray(im, dtype=float) / 255.0
    out = np.zeros((rows, cols)); oy=(rows-nh)//2; ox=(cols-nw)//2
    out[oy:oy+nh, ox:ox+nw] = g
    m = out >= thresh
    if keep_largest and m.any(): m = _largest_cc(m)
    return ["".join('#' if m[r, c] else '.' for c in range(cols)) for r in range(rows)]

def from_emoji(ch, cols, rows, **kw): return to_mask(_emoji_coverage(ch), cols, rows, **kw)
def from_glyph(ch, cols, rows, font=SYMBOL, **kw): return to_mask(_glyph_coverage(ch, font), cols, rows, **kw)
def from_png(path, cols, rows, **kw):
    im = Image.open(path).convert("RGBA"); a = im.split()[-1]
    if np.asarray(a).max() == 0: a = im.convert("L")   # no alpha → use luminance
    return to_mask(a, cols, rows, **kw)

if __name__ == "__main__":
    # quick visual test of emoji silhouettes at grid 20
    for ch,name in [("🐱","cat"),("🐟","fish"),("⭐","star"),("❤️","heart"),
                    ("🌙","moon"),("🏠","house"),("🌸","flower"),("🔑","key"),
                    ("☂️","umbrella"),("🐢","turtle"),("🍎","apple"),("✈️","plane")]:
        m = from_emoji(ch, 20, 20)
        filled = sum(row.count('#') for row in m)
        print(f"\n=== {name} ({ch}) — {filled} cells ===")
        for row in m: print(row)

# ── outline / line-art masks (matches the reference look) ─────────────────────
import numpy as _np
def _bool_grid(cov, cols, rows, thresh=0.40, fill=0.94):
    a = _np.asarray(cov, dtype=float) / 255.0
    ys, xs = _np.where(a > 0.12)
    if len(xs) == 0: return _np.zeros((rows, cols), bool)
    a = a[ys.min():ys.max()+1, xs.min():xs.max()+1]; h, w = a.shape
    s = min(cols/w, rows/h) * fill
    nw, nh = max(1, round(w*s)), max(1, round(h*s))
    im = Image.fromarray((a*255).astype("uint8")).resize((nw, nh), Image.LANCZOS)
    g = _np.asarray(im, dtype=float) / 255.0
    out = _np.zeros((rows, cols)); oy=(rows-nh)//2; ox=(cols-nw)//2
    out[oy:oy+nh, ox:ox+nw] = g
    return out >= thresh

def _erode(m, k=1):
    e = m.copy()
    for _ in range(k):
        e2 = e & _np.roll(e,1,0) & _np.roll(e,-1,0) & _np.roll(e,1,1) & _np.roll(e,-1,1)
        e = e2
    return e

def _grid_to_rows(m):
    rows, cols = m.shape
    return ["".join('#' if m[r,c] else '.' for c in range(cols)) for r in range(rows)]

def outline(cov, cols, rows, thickness=2, **kw):
    m = _bool_grid(cov, cols, rows, **kw)
    ring = m & ~_erode(m, thickness)          # morphological gradient = contour band
    return _grid_to_rows(ring)

def outline_emoji(ch, cols, rows, thickness=2): return outline(_emoji_coverage(ch), cols, rows, thickness)
def outline_glyph(ch, cols, rows, thickness=2, font=SYMBOL): return outline(_glyph_coverage(ch, font), cols, rows, thickness)
